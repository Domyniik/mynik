import Foundation
import SwiftData
import UserNotifications

/// Agenda as notificações locais: contas a pagar e prazos da agenda (carro, documentos...).
///
/// Em vez de seguir cada conta individualmente, apaga e volta a criar todos
/// os lembretes sempre que os dados mudam: é simples e nunca fica dessincronizado.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let presenter = ForegroundPresenter()

    private init() {
        center.delegate = presenter
    }

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.billRemindersEnabled) as? Bool ?? true
    }

    var daysBefore: Int {
        UserDefaults.standard.object(forKey: SettingsKey.billReminderDaysBefore) as? Int ?? 1
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Pede autorização se ainda não foi pedida. Devolve `true` se pode notificar.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Lembretes dos prazos do carro, documentos e follow-ups.
    var isAgendaEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.agendaRemindersEnabled) as? Bool ?? true
    }

    /// Volta a agendar os lembretes das contas por pagar e dos prazos da agenda.
    func rescheduleReminders(in context: ModelContext) async {
        await removePendingReminders()
        await scheduleWeeklyReview()

        var reminders = isEnabled ? billReminders(in: context) : []
        if isAgendaEnabled {
            reminders += AgendaReminderPlanner().reminders(for: LifeAgenda.allItems(in: context))
        }
        guard !reminders.isEmpty, await requestAuthorizationIfNeeded() else { return }

        // O sistema só guarda 64 notificações pendentes: ficam as mais próximas.
        let nearest = reminders.sorted { $0.fireDate < $1.fireDate }.prefix(BillReminderPlanner.maximumReminders)
        for reminder in nearest {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static let weeklyReviewIdentifier = "weekly-review"

    /// Revisão semanal ao domingo às 19h (repetida). Só agenda se já houver
    /// permissão: não pede notificações só por causa disto.
    func scheduleWeeklyReview() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyReviewIdentifier])
        let enabled = UserDefaults.standard.object(forKey: SettingsKey.weeklyReviewReminder) as? Bool ?? true
        guard enabled, await authorizationStatus() == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Revisão da semana"
        content.body = "Vê como correram os gastos, as contas, as tarefas e os hábitos desta semana."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 19, minute: 0, weekday: 1), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: Self.weeklyReviewIdentifier, content: content, trigger: trigger))
    }

    private func billReminders(in context: ModelContext) -> [BillReminderPlanner.Reminder] {
        let descriptor = FetchDescriptor<Bill>(
            predicate: #Predicate { !$0.isPaid },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        guard let bills = try? context.fetch(descriptor) else { return [] }
        return BillReminderPlanner(daysBefore: daysBefore).reminders(
            for: bills.map {
                .init(
                    title: $0.title,
                    formattedAmount: Currency.format($0.amount, code: $0.currencyCode),
                    dueDate: $0.dueDate
                )
            }
        )
    }

    private func removePendingReminders() async {
        let prefixes = [BillReminderPlanner.identifierPrefix, AgendaReminderPlanner.identifierPrefix]
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { identifier in prefixes.contains { identifier.hasPrefix($0) } }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Mostra a notificação mesmo com a app aberta.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
