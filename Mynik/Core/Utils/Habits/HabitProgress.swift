import Foundation

/// Progresso de um hábito: sequência, semana atual e últimos dias.
nonisolated struct HabitProgress: Equatable, Sendable {
    /// Dias seguidos cumpridos até hoje (ou até ontem, se hoje ainda não foi marcado).
    let streak: Int
    /// Dias cumpridos nesta semana (segunda a domingo).
    let thisWeek: Int
    let targetPerWeek: Int
    /// Os últimos 7 dias, do mais antigo para hoje.
    let lastSevenDays: [Bool]
    let isDoneToday: Bool

    var isWeekGoalReached: Bool { thisWeek >= targetPerWeek }

    init(days: Set<Date>, targetPerWeek: Int, now: Date = .now, calendar: Calendar = .mondayFirst) {
        let today = calendar.startOfDay(for: now)
        let done = Set(days.map { calendar.startOfDay(for: $0) })
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }

        isDoneToday = done.contains(today)
        var count = 0
        var cursor = isDoneToday ? 0 : -1
        while done.contains(day(cursor)) {
            count += 1
            cursor -= 1
        }
        streak = count

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        thisWeek = done.filter { $0 >= weekStart && $0 <= today }.count
        self.targetPerWeek = targetPerWeek
        lastSevenDays = (-6...0).map { done.contains(day($0)) }
    }
}

extension Calendar {
    /// Calendário com a semana a começar à segunda (como em Espanha e Portugal).
    nonisolated static var mondayFirst: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}
