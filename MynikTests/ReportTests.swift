import Foundation
import Testing
@testable import Mynik

@MainActor
struct ReportTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func groupsExpensesByCategoryLargestFirst() {
        let food = Mynik.Category(name: "Alimentação", symbolName: "cart", color: .orange, kind: .expense)
        let fun = Mynik.Category(name: "Lazer", symbolName: "gamecontroller", color: .purple, kind: .expense)
        let transactions = [
            FinanceTransaction(title: "A", amount: 10, kind: .expense, date: date(2026, 11, 1), category: fun),
            FinanceTransaction(title: "B", amount: 30, kind: .expense, date: date(2026, 11, 2), category: food),
            FinanceTransaction(title: "C", amount: 25, kind: .expense, date: date(2026, 11, 3), currencyCode: "BRL", category: food),
            FinanceTransaction(title: "D", amount: 7, kind: .expense, date: date(2026, 11, 4)),
            FinanceTransaction(title: "E", amount: 999, kind: .income, date: date(2026, 11, 4)),
            FinanceTransaction(title: "F", amount: 999, kind: .expense, date: date(2026, 10, 4), category: fun),
        ]

        let slices = FinanceReport.expensesByCategory(
            month: date(2026, 11, 10),
            transactions: transactions,
            converter: CurrencyConverter(brlPerEUR: 5),
            calendar: calendar
        )

        #expect(slices.map(\.name) == ["Alimentação", "Lazer", "Sem categoria"])
        #expect(slices.map(\.amount) == [35, 10, 7])
        #expect(slices.first?.color == .orange)
    }

    @Test func monthlyTotalsCoverLastSixMonthsOldestFirst() {
        let transactions = [
            FinanceTransaction(title: "Salário", amount: 2000, kind: .income, date: date(2026, 11, 1)),
            FinanceTransaction(title: "Renda", amount: 750, kind: .expense, date: date(2026, 9, 5)),
            FinanceTransaction(title: "Antigo", amount: 1, kind: .expense, date: date(2026, 5, 5)),
        ]

        let totals = FinanceReport.monthlyTotals(endingAt: date(2026, 11, 19), transactions: transactions, calendar: calendar)

        #expect(totals.count == 6)
        #expect(totals.first?.month == date(2026, 6, 1))
        #expect(totals.last?.month == date(2026, 11, 1))
        #expect(totals.last?.income == 2000)
        #expect(totals[3].expenses == 750)
        #expect(totals.reduce(0) { $0 + $1.expenses } == 750)
    }
}
