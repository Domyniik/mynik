import Foundation
import Testing
@testable import Mynik

@MainActor
struct BillDueSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let calendar = Calendar.current

    private func bill(_ title: String, _ amount: Decimal, daysFromNow: Int, paid: Bool = false, currency: String = "EUR") -> Bill {
        let date = calendar.date(byAdding: .day, value: daysFromNow, to: now)!
        let bill = Bill(title: title, amount: amount, dueDate: date, currencyCode: currency)
        bill.isPaid = paid
        return bill
    }

    @Test func nothingDueTodayHasNoActivity() {
        #expect(BillDueSummary(bills: [bill("Luz", 50, daysFromNow: 2)], now: now) == nil)
        #expect(BillDueSummary(bills: [bill("Água", 20, daysFromNow: 0, paid: true)], now: now) == nil)
    }

    @Test func summarizesTodayAndOverdue() throws {
        let bills = [
            bill("Internet", 30, daysFromNow: 0),
            bill("Luz", 60, daysFromNow: -3),
            bill("Ginásio", 40, daysFromNow: 5),
        ]
        let summary = try #require(BillDueSummary(bills: bills, now: now))
        // A mais antiga (atrasada) primeiro.
        #expect(summary.title == "Luz")
        #expect(summary.amount == 60)
        #expect(summary.count == 2)
        #expect(summary.total == 90)
        #expect(summary.hasOverdue)
    }

    @Test func convertsOtherCurrencies() throws {
        let converter = CurrencyConverter(brlPerEUR: 6)
        let summary = try #require(BillDueSummary(bills: [bill("Netflix BR", 60, daysFromNow: 0, currency: "BRL")], converter: converter, now: now))
        #expect(summary.amount == 10)
        #expect(!summary.hasOverdue)
    }
}
