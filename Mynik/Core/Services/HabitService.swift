import Foundation
import SwiftData

/// Marcar e desmarcar hábitos, um registo por dia.
@MainActor
enum HabitService {
    static func days(of habit: Habit) -> Set<Date> {
        Set((habit.checks ?? []).map(\.day))
    }

    static func progress(of habit: Habit, now: Date = .now, calendar: Calendar = .mondayFirst) -> HabitProgress {
        HabitProgress(days: days(of: habit), targetPerWeek: habit.targetPerWeek, now: now, calendar: calendar)
    }

    static func isDone(_ habit: Habit, on date: Date = .now, calendar: Calendar = .mondayFirst) -> Bool {
        let day = calendar.startOfDay(for: date)
        return (habit.checks ?? []).contains { calendar.isDate($0.day, inSameDayAs: day) }
    }

    /// Alterna o dia: marca se não estava feito, desmarca se estava.
    static func toggle(_ habit: Habit, on date: Date = .now, in context: ModelContext, calendar: Calendar = .mondayFirst) {
        let day = calendar.startOfDay(for: date)
        let existing = (habit.checks ?? []).filter { calendar.isDate($0.day, inSameDayAs: day) }
        if existing.isEmpty {
            context.insert(HabitCheck(day: day, habit: habit))
        } else {
            existing.forEach(context.delete)
        }
        try? context.save()
    }
}
