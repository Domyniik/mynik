import Foundation

/// Texto curto para datas de vencimento ("Vence hoje", "Vence em 3 dias"...).
nonisolated enum DueDateText {
    static func daysUntil(_ date: Date, from now: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func isOverdue(_ date: Date, from now: Date = .now, calendar: Calendar = .current) -> Bool {
        daysUntil(date, from: now, calendar: calendar) < 0
    }

    static func describe(_ date: Date, from now: Date = .now, calendar: Calendar = .current) -> String {
        switch daysUntil(date, from: now, calendar: calendar) {
        case ..<(-1): "Atrasada \(-daysUntil(date, from: now, calendar: calendar)) dias"
        case -1: "Atrasada 1 dia"
        case 0: "Vence hoje"
        case 1: "Vence amanhã"
        case let days: "Vence em \(days) dias"
        }
    }
}
