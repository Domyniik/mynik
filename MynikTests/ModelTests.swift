import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct ModelTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
    }

    @Test func expenseHasNegativeSignedAmount() {
        let expense = FinanceTransaction(title: "Café", amount: 1.20, kind: .expense)
        let income = FinanceTransaction(title: "Salário", amount: 1000, kind: .income)

        #expect(expense.signedAmount == -1.20)
        #expect(income.signedAmount == 1000)
    }

    @Test func accountBalanceIncludesInitialBalanceAndTransactions() throws {
        let account = Account(name: "Banco", initialBalance: 100)
        context.insert(account)
        context.insert(FinanceTransaction(title: "Salário", amount: 50, kind: .income, account: account))
        context.insert(FinanceTransaction(title: "Compras", amount: 30, kind: .expense, account: account))
        try context.save()

        #expect(account.balance == 120)
    }

    @Test func seederIsIdempotent() throws {
        try DefaultDataSeeder.seedIfNeeded(in: context)
        let firstCount = try context.fetchCount(FetchDescriptor<Mynik.Category>())
        try DefaultDataSeeder.seedIfNeeded(in: context)

        #expect(firstCount > 0)
        #expect(try context.fetchCount(FetchDescriptor<Mynik.Category>()) == firstCount)
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 1)
    }
}
