import Foundation
import Testing
@testable import Mynik

@MainActor
struct SpendingTrendTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ day: Int, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .distantPast
    }

    @Test func accumulatesExpensesUpToToday() {
        let transactions = [
            FinanceTransaction(title: "Salário", amount: 2000, kind: .income, date: date(1)),
            FinanceTransaction(title: "Renda", amount: 750, kind: .expense, date: date(2)),
            FinanceTransaction(title: "Café", amount: 3, kind: .expense, date: date(4)),
            FinanceTransaction(title: "Outubro", amount: 99, kind: .expense, date: date(30, month: 10)),
        ]
        let series = SpendingTrend.cumulativeExpenses(month: date(4), transactions: transactions, calendar: calendar)
        #expect(series == [0, 750, 750, 753])
    }

    @Test func emptyMonthIsFlat() {
        let series = SpendingTrend.cumulativeExpenses(month: date(3), transactions: [], calendar: calendar)
        #expect(series == [0, 0, 0])
    }
}
