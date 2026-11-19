import Foundation
import Testing
@testable import Mynik

struct TodayTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 22)) ?? .distantPast
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now) ?? now
    }

    @Test(arguments: [
        (0, "Vence hoje"),
        (1, "Vence amanhã"),
        (5, "Vence em 5 dias"),
        (-1, "Atrasada 1 dia"),
        (-3, "Atrasada 3 dias"),
    ])
    func describesDueDates(offset: Int, expected: String) {
        #expect(DueDateText.describe(day(offset), from: now, calendar: calendar) == expected)
    }

    @Test func overdueOnlyBeforeToday() {
        #expect(DueDateText.isOverdue(day(-1), from: now, calendar: calendar))
        #expect(!DueDateText.isOverdue(day(0), from: now, calendar: calendar))
    }
}
