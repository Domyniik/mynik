import Foundation
import Testing
@testable import Mynik

struct BillReminderPlannerTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)) ?? .distantPast
    }

    private func bill(_ title: String, due day: Int) -> BillReminderPlanner.BillInfo {
        .init(title: title, formattedAmount: "750,00 €", dueDate: date(day, hour: 15))
    }

    @Test func schedulesEarlyAndDueDayRemindersAtNine() {
        let planner = BillReminderPlanner(daysBefore: 1, hour: 9, calendar: calendar)
        let reminders = planner.reminders(for: [bill("Renda", due: 25)], now: date(19, hour: 22))

        #expect(reminders.map(\.fireDate) == [date(24, hour: 9), date(25, hour: 9)])
        #expect(reminders.first?.title == "Renda vence amanhã")
        #expect(reminders.last?.title == "Renda vence hoje")
    }

    @Test func skipsRemindersInThePast() {
        let planner = BillReminderPlanner(daysBefore: 3, hour: 9, calendar: calendar)
        // Vence dia 21 → aviso antecipado (dia 18) já passou; o do dia ainda não.
        let reminders = planner.reminders(for: [bill("Luz", due: 21)], now: date(19, hour: 22))

        #expect(reminders.count == 1)
        #expect(reminders.first?.fireDate == date(21, hour: 9))
    }

    @Test func zeroDaysBeforeOnlyRemindsOnDueDay() {
        let planner = BillReminderPlanner(daysBefore: 0, hour: 9, calendar: calendar)
        let reminders = planner.reminders(for: [bill("Água", due: 28)], now: date(19))

        #expect(reminders.map(\.title) == ["Água vence hoje"])
    }

    @Test func capsAtSystemLimit() {
        let planner = BillReminderPlanner(daysBefore: 1, hour: 9, calendar: calendar)
        let bills = (0..<50).map { bill("Conta \($0)", due: 25) }
        let reminders = planner.reminders(for: bills, now: date(19))

        #expect(reminders.count == BillReminderPlanner.maximumReminders)
        #expect(Set(reminders.map(\.identifier)).count == reminders.count)
    }
}
