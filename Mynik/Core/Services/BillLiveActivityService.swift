import Foundation
import SwiftData
import OSLog
#if os(iOS)
import ActivityKit
#endif

/// Resumo das contas por pagar hoje (e atrasadas), base da Live Activity.
struct BillDueSummary: Equatable {
    var title: String
    var amount: Decimal
    var count: Int
    var total: Decimal
    var hasOverdue: Bool

    /// `nil` quando não há nada a pagar hoje.
    init?(bills: [Bill], converter: CurrencyConverter = CurrencyConverter(), now: Date = .now, calendar: Calendar = .current) {
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let due = bills
            .filter { !$0.isPaid && $0.dueDate < endOfToday }
            .sorted { $0.dueDate < $1.dueDate }
        guard let first = due.first else { return nil }
        title = first.title
        amount = converter.convert(first.amount, from: first.currencyCode)
        count = due.count
        total = due.reduce(0) { $0 + converter.convert($1.amount, from: $1.currencyCode) }
        hasOverdue = first.dueDate < calendar.startOfDay(for: now)
    }
}

/// Mantém a Live Activity da conta que vence hoje alinhada com os dados.
/// Só há atualizações locais (sem push remoto, que exige o plano pago da Apple).
@MainActor
enum BillLiveActivityService {
    static var isEnabled: Bool {
        AppEnvironment.defaults.object(forKey: SettingsKey.billLiveActivity) as? Bool ?? true
    }

    static func sync(in context: ModelContext, converter: CurrencyConverter, now: Date = .now) {
        #if os(iOS)
        guard !AppEnvironment.isRunningTests else { return }
        let bills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        let summary = isEnabled ? BillDueSummary(bills: bills, converter: converter, now: now) : nil
        Task { await apply(summary, now: now) }
        #endif
    }

    private static let logger = Logger(subsystem: "com.domynik.mynik", category: "LiveActivity")

    #if os(iOS)
    private static func apply(_ summary: BillDueSummary?, now: Date) async {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let activities = Activity<BillDueActivityAttributes>.activities

        guard let summary else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let state = BillDueActivityAttributes.ContentState(
            title: summary.title,
            amountText: Currency.format(summary.amount),
            count: summary.count,
            totalText: Currency.format(summary.total),
            hasOverdue: summary.hasOverdue
        )
        // Desaparece sozinha no fim do dia se a app não voltar a abrir.
        let content = ActivityContent(state: state, staleDate: calendar.date(byAdding: .day, value: 1, to: day))

        // Atividades de outros dias terminam; a de hoje é atualizada.
        var current: Activity<BillDueActivityAttributes>?
        for activity in activities {
            if activity.attributes.day == day, current == nil {
                current = activity
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        if let current {
            if current.content.state != state { await current.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: BillDueActivityAttributes(day: day), content: content)
            } catch {
                logger.error("Live Activity não iniciada: \(String(describing: error), privacy: .public)")
            }
        } else {
            logger.info("Live Activities desligadas pelo utilizador")
        }
    }
    #endif
}
