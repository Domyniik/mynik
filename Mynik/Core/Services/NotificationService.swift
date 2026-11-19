import Foundation
import SwiftData
import UserNotifications

/// Agenda as notificações locais de vencimento das contas a pagar.
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

    /// Volta a agendar os lembretes de todas as contas por pagar.
    func rescheduleBillReminders(in context: ModelContext) async {
        await removeBillReminders()
        guard isEnabled else { return }

        let descriptor = FetchDescriptor<Bill>(
            predicate: #Predicate { !$0.isPaid },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        guard let bills = try? context.fetch(descriptor), !bills.isEmpty else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let planner = BillReminderPlanner(daysBefore: daysBefore)
        let reminders = planner.reminders(
            for: bills.map {
                .init(
                    title: $0.title,
                    formattedAmount: Currency.format($0.amount, code: $0.currencyCode),
                    dueDate: $0.dueDate
                )
            }
        )

        for reminder in reminders {
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

    private func removeBillReminders() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(BillReminderPlanner.identifierPrefix) }
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
