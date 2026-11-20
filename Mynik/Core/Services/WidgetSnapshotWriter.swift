import Foundation
import SwiftData
import WidgetKit

/// Mantém o `WidgetSnapshot` do App Group igual aos dados da app.
@MainActor
enum WidgetSnapshotWriter {
    /// Contas incluídas: as atrasadas e as que vencem nos próximos 30 dias.
    static let billWindowDays = 30
    static let maxBills = 8

    static func makeSnapshot(
        in context: ModelContext,
        converter: CurrencyConverter,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> WidgetSnapshot {
        let interval = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        let start = interval.start
        let end = interval.end
        let transactions = try context.fetch(FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))
        let summary = MonthSummary(month: now, transactions: transactions, converter: converter, calendar: calendar)

        let limit = calendar.date(byAdding: .day, value: billWindowDays + 1, to: calendar.startOfDay(for: now)) ?? now
        var billsDescriptor = FetchDescriptor<Bill>(
            predicate: #Predicate { !$0.isPaid && $0.dueDate < limit },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        billsDescriptor.fetchLimit = maxBills
        let bills = try context.fetch(billsDescriptor).map {
            WidgetSnapshot.BillItem(id: $0.uid, title: $0.title, amount: $0.amount, currencyCode: $0.currencyCode, dueDate: $0.dueDate)
        }

        return WidgetSnapshot(generatedAt: now, month: start, income: summary.income, expenses: summary.expenses, bills: bills)
    }

    /// Escreve o resumo e, se mudou, pede aos widgets para se redesenharem.
    static func update(in context: ModelContext, converter: CurrencyConverter) {
        guard !AppEnvironment.isRunningTests else { return }
        guard let snapshot = try? makeSnapshot(in: context, converter: converter) else { return }
        // Só reescreve (e gasta o orçamento de atualizações do WidgetKit) quando algo mudou.
        var previous = WidgetSnapshot.load()
        previous?.generatedAt = snapshot.generatedAt
        guard previous != snapshot else { return }
        guard (try? snapshot.save()) == true else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
