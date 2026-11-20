import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct QuickEntryTests {
    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
        return container
    }

    @Test(arguments: [
        ("Alimentação", "Alimentação"),
        ("alimentacao", "Alimentação"),
        (" SAÚDE ", "Saúde"),
        ("comida", "Alimentação"),
        ("gasolina", "Carro"),
        ("farmácia", "Saúde"),
    ])
    func matchesSpokenCategory(spoken: String, expected: String) throws {
        let container = try makeContainer()
        #expect(QuickEntryService.category(matching: spoken, in: container.mainContext)?.name == expected)
    }

    @Test func unknownWordsMatchNothing() throws {
        let container = try makeContainer()
        #expect(QuickEntryService.category(matching: "xpto", in: container.mainContext) == nil)
        #expect(QuickEntryService.category(matching: "  ", in: container.mainContext) == nil)
        // Categorias de receita não servem para gastos.
        #expect(QuickEntryService.category(matching: "Salário", in: container.mainContext) == nil)
    }

    @Test func addsExpenseOnMainAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let food = QuickEntryService.category(matching: "comida", in: context)
        let transaction = try QuickEntryService.addExpense(amount: 12.5, category: food, title: nil, in: context)
        #expect(transaction.title == "Alimentação")
        #expect(transaction.kind == .expense)
        #expect(transaction.account?.name == "Conta principal")
        #expect(try context.fetchCount(FetchDescriptor<FinanceTransaction>()) == 1)
        #expect(throws: QuickEntryError.self) {
            try QuickEntryService.addExpense(amount: 0, category: nil, title: "x", in: context)
        }
    }

    @Test func intentRegistersExpenseWithCategory() async throws {
        let context = SharedModelContainer.shared.mainContext
        let category = try #require(QuickEntryService.category(matching: "Lazer", in: context))
        let note = "Cinema \(UUID().uuidString)"
        _ = try await AddExpenseIntent(amount: 7.9, category: CategoryEntity(category), note: note).perform()

        let saved = try context.fetch(FetchDescriptor<FinanceTransaction>(predicate: #Predicate { $0.title == note }))
        #expect(saved.count == 1)
        #expect(saved.first?.amount == Decimal(string: "7.9"))
        #expect(saved.first?.category?.name == "Lazer")
    }

    @Test func categoryQueryFindsBySpokenName() async throws {
        let found = try await CategoryQuery().entities(matching: "supermercado")
        #expect(found.map(\.name) == ["Alimentação"])
        let suggested = try await CategoryQuery().suggestedEntities()
        #expect(suggested.contains { $0.name == "Outros" })
        #expect(!suggested.contains { $0.name == "Salário" })
    }
}
