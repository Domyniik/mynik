import Foundation

/// Calcula os lembretes de vencimento das contas por pagar.
///
/// É lógica pura (sem UserNotifications) para poder ser testada.
/// Para cada conta: um aviso `daysBefore` dias antes e outro no próprio dia,
/// sempre à `hour` indicada e só se ainda estiverem no futuro.
nonisolated struct BillReminderPlanner {
    struct BillInfo: Sendable {
        let title: String
        let formattedAmount: String
        let dueDate: Date
    }

    struct Reminder: Equatable, Sendable {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
    }

    static let identifierPrefix = "bill-reminder-"
    /// O iOS só guarda 64 notificações pendentes por app.
    static let maximumReminders = 60

    var daysBefore = 1
    var hour = 9
    var calendar = Calendar.current

    func reminders(for bills: [BillInfo], now: Date = .now) -> [Reminder] {
        var reminders: [Reminder] = []

        for (index, bill) in bills.enumerated() {
            let dueDay = calendar.startOfDay(for: bill.dueDate)

            if daysBefore > 0,
               let earlyDay = calendar.date(byAdding: .day, value: -daysBefore, to: dueDay),
               let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: earlyDay),
               fireDate > now {
                let when = daysBefore == 1 ? "amanhã" : "em \(daysBefore) dias"
                reminders.append(
                    Reminder(
                        identifier: "\(Self.identifierPrefix)\(index)-early",
                        title: "\(bill.title) vence \(when)",
                        body: "\(bill.formattedAmount) a pagar.",
                        fireDate: fireDate
                    )
                )
            }

            if let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dueDay),
               fireDate > now {
                reminders.append(
                    Reminder(
                        identifier: "\(Self.identifierPrefix)\(index)-due",
                        title: "\(bill.title) vence hoje",
                        body: "\(bill.formattedAmount) a pagar. Marca como paga no Mynik.",
                        fireDate: fireDate
                    )
                )
            }
        }

        return Array(reminders.sorted { $0.fireDate < $1.fireDate }.prefix(Self.maximumReminders))
    }
}
