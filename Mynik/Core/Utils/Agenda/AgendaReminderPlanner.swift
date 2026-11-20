import Foundation

/// Calcula as notificações locais dos itens da agenda (lógica pura, testável).
nonisolated struct AgendaReminderPlanner {
    static let identifierPrefix = "agenda-reminder-"

    var hour = 9
    var calendar = Calendar.current

    func reminders(for items: [AgendaItem], now: Date = .now) -> [BillReminderPlanner.Reminder] {
        var reminders: [BillReminderPlanner.Reminder] = []
        for item in items {
            let dueDay = calendar.startOfDay(for: item.date)
            for days in Set(item.remindDaysBefore) {
                guard let day = calendar.date(byAdding: .day, value: -days, to: dueDay),
                      let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                      fireDate > now
                else { continue }
                let when = switch days {
                case 0: "hoje"
                case 1: "amanhã"
                default: "em \(days) dias"
                }
                reminders.append(
                    .init(
                        identifier: "\(Self.identifierPrefix)\(item.id)-\(days)",
                        title: "\(item.title): \(item.dueWord.lowercased()) \(when)",
                        body: item.detail.isEmpty ? "Vê os detalhes no Mynik." : item.detail,
                        fireDate: fireDate
                    )
                )
            }
        }
        return reminders.sorted { $0.fireDate < $1.fireDate }
    }
}
