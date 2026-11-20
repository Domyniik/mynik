import Foundation
import SwiftData

/// Um hábito a acompanhar (ex.: ginásio, ler, sem gastos supérfluos).
///
/// Compatível com CloudKit: tudo com valor por omissão e relações opcionais.
@Model
final class Habit {
    var uid: String = UUID().uuidString
    var name: String = ""
    /// Nome de um SF Symbol.
    var symbolName: String = "checkmark.circle"
    /// Nome de uma cor de `CategoryColor`.
    var colorName: String = CategoryColor.green.rawValue
    /// Quantos dias por semana (1–7) contam como objetivo cumprido.
    var targetPerWeek: Int = 7
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \HabitCheck.habit)
    var checks: [HabitCheck]? = []

    var color: CategoryColor {
        CategoryColor(rawValue: colorName) ?? .green
    }

    init(name: String, symbolName: String = "checkmark.circle", color: CategoryColor = .green, targetPerWeek: Int = 7) {
        self.name = name
        self.symbolName = symbolName
        self.colorName = color.rawValue
        self.targetPerWeek = min(7, max(1, targetPerWeek))
    }
}

/// Um dia em que o hábito foi cumprido.
@Model
final class HabitCheck {
    var uid: String = UUID().uuidString
    /// Início do dia (no calendário do utilizador).
    var day: Date = Date.now
    var createdAt: Date = Date.now

    var habit: Habit?

    init(day: Date, habit: Habit? = nil) {
        self.day = day
        self.habit = habit
    }
}
