import Foundation
import Testing
@testable import Mynik

@MainActor
struct FinanceTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func monthSummaryCountsSelectedMonthConvertingBRL() {
        let transactions = [
            FinanceTransaction(title: "Salário", amount: 2000, kind: .income, date: date(2026, 11, 1)),
            FinanceTransaction(title: "Renda", amount: 750, kind: .expense, date: date(2026, 11, 5)),
            FinanceTransaction(title: "Café", amount: 3, kind: .expense, date: date(2026, 11, 20)),
            FinanceTransaction(title: "Mês passado", amount: 100, kind: .expense, date: date(2026, 10, 31)),
            FinanceTransaction(title: "Em reais", amount: 50, kind: .expense, date: date(2026, 11, 6), currencyCode: "BRL"),
        ]

        let converter = CurrencyConverter(brlPerEUR: 5)
        let summary = MonthSummary(month: date(2026, 11, 15), transactions: transactions, converter: converter, calendar: calendar)

        #expect(summary.income == 2000)
        #expect(summary.expenses == 763) // 750 + 3 + 50 BRL (= 10 EUR)
        #expect(summary.balance == 1237)
    }

    @Test func groupsTransactionsByMonthNewestFirst() {
        let transactions = [
            FinanceTransaction(title: "A", amount: 1, kind: .expense, date: date(2026, 10, 3)),
            FinanceTransaction(title: "B", amount: 1, kind: .expense, date: date(2026, 11, 1)),
            FinanceTransaction(title: "C", amount: 1, kind: .expense, date: date(2026, 11, 9)),
        ]

        let groups = TransactionMonthGroup.group(transactions, calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups.first?.transactions.map(\.title) == ["C", "B"])
        #expect(groups.last?.transactions.map(\.title) == ["A"])
        #expect(groups.first?.title == "Novembro de 2026")
    }

    @Test func draftRequiresTitleAndPositiveAmount() {
        var draft = TransactionDraft()
        #expect(!draft.isValid)

        draft.title = "  Almoço "
        draft.amount = 12
        #expect(draft.isValid)

        let transaction = draft.makeTransaction()
        #expect(transaction.title == "Almoço")
        #expect(transaction.kind == .expense)
    }
}
