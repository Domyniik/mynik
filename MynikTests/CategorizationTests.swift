import Foundation
import SwiftData
import Testing
@testable import Mynik

struct MerchantCategoryRulesTests {
    private let expenseNames = ["Alimentação", "Casa", "Transporte", "Carro", "Saúde", "Lazer", "Compras", "Assinaturas", "Outros"]

    @Test(arguments: [
        ("MERCADONA VALENCIA 1234", "Alimentação"),
        ("Compra Lidl Madrid", "Alimentação"),
        ("REPSOL E.S. 4521", "Carro"),
        ("Uber *Trip", "Transporte"),
        ("Uber Eats pedido", "Alimentação"),
        ("NETFLIX.COM", "Assinaturas"),
        ("Amazon Prime", "Assinaturas"),
        ("AMAZON EU SARL", "Compras"),
        ("Farmácia Central", "Saúde"),
        ("Iberdrola factura", "Casa"),
        ("Cinesa Proyecciones", "Lazer"),
    ])
    func knownMerchants(title: String, expected: String) {
        let rules = MerchantCategoryRules()
        let suggestion = rules.suggest(for: title, among: expenseNames)
        #expect(suggestion?.categoryName == expected)
        #expect(suggestion?.source == .rules)
    }

    @Test func shortWordsOnlyMatchWholeWords() {
        let rules = MerchantCategoryRules()
        // "dia" é o supermercado, mas não pode apanhar "diario".
        #expect(rules.suggest(for: "Dia %", among: expenseNames)?.categoryName == "Alimentação")
        #expect(rules.suggest(for: "Diario de Noticias", among: expenseNames) == nil)
    }

    @Test func historyWinsOverKeywords() {
        let old = Date(timeIntervalSince1970: 0)
        let rules = MerchantCategoryRules(history: [
            .init(title: "Mercadona", categoryName: "Casa", date: old),
            .init(title: "Mercadona", categoryName: "Lazer", date: old.addingTimeInterval(60)),
        ])
        // O mais recente ganha.
        #expect(rules.suggest(for: "MERCADONA", among: expenseNames) == .init(categoryName: "Lazer", source: .history))
    }

    @Test func historyMatchesSameMerchantWithDifferentSuffix() {
        let rules = MerchantCategoryRules(history: [
            .init(title: "Padaria Ribeiro 0012", categoryName: "Alimentação", date: .now),
        ])
        #expect(rules.suggest(for: "PADARIA RIBEIRO 0098", among: expenseNames)?.source == .history)
        #expect(MerchantCategoryRules.merchantKey("Compra Apple Pay Zara 33") == "zara")
    }

    @Test func onlySuggestsExistingCategories() {
        let rules = MerchantCategoryRules(history: [.init(title: "Ginásio", categoryName: "Apagada", date: .now)])
        #expect(rules.suggest(for: "Repsol", among: ["Alimentação"]) == nil)
        #expect(rules.suggest(for: "Ginásio", among: ["Alimentação"]) == nil)
        // Uma categoria criada pelo utilizador cujo nome aparece na descrição.
        #expect(rules.suggest(for: "Mensalidade ginásio", among: ["Ginásio"])?.categoryName == "Ginásio")
    }

    @Test func emptyTitleSuggestsNothing() {
        #expect(MerchantCategoryRules().suggest(for: "  ", among: expenseNames) == nil)
    }
}

@MainActor
struct CategorizationServiceTests {
    /// O contentor tem de viver enquanto o contexto é usado.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }

    private func makeContext() throws -> ModelContext {
        container.mainContext
    }

    @Test func fallsBackToRulesWithoutModel() async throws {
        let context = try makeContext()
        let result = await CategorizationService.suggest(title: "Repsol 1234", kind: .expense, in: context, useModel: false)
        #expect(result?.category.name == "Carro")
        #expect(result?.source == .rules)
    }

    @Test func usesHistoryOfSameKind() async throws {
        let context = try makeContext()
        let leisure = try #require(QuickEntryService.category(matching: "Lazer", in: context))
        context.insert(FinanceTransaction(title: "Padel Club", amount: 8, kind: .expense, category: leisure))
        try context.save()

        let result = await CategorizationService.suggest(title: "padel club", kind: .expense, in: context, useModel: false)
        #expect(result?.category == leisure)
        #expect(result?.source == .history)
        // Receitas não usam categorias de gasto.
        let income = await CategorizationService.suggest(title: "padel club", kind: .income, in: context, useModel: false)
        #expect(income == nil)
    }

    @Test func ruleCategorizerHandlesBothKinds() throws {
        let context = try makeContext()
        let rules = RuleCategorizer(in: context)
        #expect(rules.category(for: "NOMINA EMPRESA SL", kind: .income)?.name == "Salário")
        #expect(rules.category(for: "Spotify AB", kind: .expense)?.name == "Assinaturas")
        #expect(rules.category(for: "Transferência", kind: .expense) == nil)
    }
}
