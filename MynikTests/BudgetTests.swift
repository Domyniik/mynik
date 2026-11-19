import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct BudgetTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar(identifier: .gregorian)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
    }

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day)) ?? .distantPast
    }

    @Test func sumsMonthlyExpensesPerCategoryConvertingBRL() throws {
        let food = Mynik.Category(name: "Alimentação", symbolName: "cart", color: .orange, kind: .expense)
        food.monthlyBudget = 100
        let fun = Mynik.Category(name: "Lazer", symbolName: "gamecontroller", color: .purple, kind: .expense)
        fun.monthlyBudget = 20
        let car = Mynik.Category(name: "Carro", symbolName: "car", color: .indigo, kind: .expense)
        let salary = Mynik.Category(name: "Salário", symbolName: "briefcase", color: .green, kind: .income)
        [food, fun, car, salary].forEach(context.insert)

        let transactions = [
            FinanceTransaction(title: "Mercado", amount: 60, kind: .expense, date: date(11, 2), category: food),
            FinanceTransaction(title: "Feira", amount: 50, kind: .expense, date: date(11, 9), currencyCode: "BRL", category: food),
            FinanceTransaction(title: "Cinema", amount: 25, kind: .expense, date: date(11, 3), category: fun),
            FinanceTransaction(title: "Outubro", amount: 500, kind: .expense, date: date(10, 30), category: food),
            FinanceTransaction(title: "Gasolina", amount: 40, kind: .expense, date: date(11, 4), category: car),
            FinanceTransaction(title: "Salário", amount: 2000, kind: .income, date: date(11, 1), category: salary),
        ]
        transactions.forEach(context.insert)
        try context.save()

        let overview = BudgetOverview(
            month: date(11, 15),
            categories: [food, fun, car, salary],
            transactions: transactions,
            converter: CurrencyConverter(brlPerEUR: 5),
            calendar: calendar
        )

        #expect(overview.lines.count == 3) // só despesas
        #expect(overview.budgeted.map(\.category.name) == ["Lazer", "Alimentação"])
        #expect(overview.budgeted.first?.isOverBudget == true)
        #expect(overview.budgeted.last?.spent == 70)   // 60 + 50 BRL (10 EUR)
        #expect(overview.budgeted.last?.remaining == 30)
        #expect(overview.unbudgeted.map(\.category.name) == ["Carro"])
        #expect(overview.totalBudget == 120)
        #expect(overview.totalSpentInBudgeted == 95)
    }
}
