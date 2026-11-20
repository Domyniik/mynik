import Foundation
import Testing
@testable import Mynik

struct CalendarDayItemTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func describesEventTimes() {
        let today = date(20, 8)
        let meeting = CalendarDayItem(id: "1", title: "Reunião", kind: .event(start: date(20, 9), end: date(20, 10, 30), isAllDay: false))
        #expect(meeting.timeText(on: today, calendar: calendar).contains("–"))
        let allDay = CalendarDayItem(id: "2", title: "Feriado", kind: .event(start: date(20, 0), end: date(21, 0), isAllDay: true))
        #expect(allDay.timeText(on: today, calendar: calendar) == "Todo o dia")
        let trip = CalendarDayItem(id: "3", title: "Viagem", kind: .event(start: date(18, 10), end: date(22, 10), isAllDay: false))
        #expect(trip.timeText(on: today, calendar: calendar) == "Todo o dia")
        let late = CalendarDayItem(id: "4", title: "Pagar", kind: .reminder(due: date(12, 9), hasTime: false))
        #expect(late.timeText(on: today, calendar: calendar).hasPrefix("Atrasado desde"))
        let noTime = CalendarDayItem(id: "5", title: "Ligar", kind: .reminder(due: date(20, 0), hasTime: false))
        #expect(noTime.timeText(on: today, calendar: calendar) == "Hoje")
    }

    @Test func sortsAllDayThenEventsThenReminders() {
        let items = [
            CalendarDayItem(id: "r", title: "Lembrete", kind: .reminder(due: date(19, 9), hasTime: true)),
            CalendarDayItem(id: "b", title: "Tarde", kind: .event(start: date(20, 15), end: date(20, 16), isAllDay: false)),
            CalendarDayItem(id: "a", title: "Manhã", kind: .event(start: date(20, 9), end: date(20, 10), isAllDay: false)),
            CalendarDayItem(id: "d", title: "Feriado", kind: .event(start: date(20, 0), end: date(21, 0), isAllDay: true)),
        ]
        #expect(CalendarDayItem.sortedForToday(items).map(\.id) == ["d", "a", "b", "r"])
    }
}
