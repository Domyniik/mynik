import Foundation
import SwiftData
import Testing
@testable import Mynik

struct SearchMatcherTests {
    @Test func ranksPrefixThenWordThenContains() {
        #expect(SearchMatcher.rank("merc", in: ["Mercadona"]) == 0)
        #expect(SearchMatcher.rank("valen", in: ["Mercadona Valencia"]) == 1)
        #expect(SearchMatcher.rank("cado", in: ["Mercadona"]) == 2)
        #expect(SearchMatcher.rank("xyz", in: ["Mercadona"]) == nil)
    }

    @Test func ignoresAccentsAndCase() {
        #expect(SearchMatcher.rank("SAUDE", in: ["Saúde"]) == 0)
    }

    @Test func secondaryFieldsRankLower() {
        #expect(SearchMatcher.rank("leite", in: ["Compras", "leite e pão"]) == 3)
        #expect(SearchMatcher.rank("  ", in: ["Compras"]) == nil)
    }
}

@MainActor
struct GlobalSearchTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }

    @Test func findsAcrossModules() throws {
        let context = container.mainContext
        context.insert(FinanceTransaction(title: "Ginásio Basic-Fit", amount: 30, kind: .expense))
        context.insert(Habit(name: "Ginásio"))
        context.insert(ProjectTask(title: "Renovar ginásio"))
        try context.save()

        let results = GlobalSearch.search("gin", in: context)
        let titles = results.map(\.title)
        #expect(titles.contains("Ginásio"))
        #expect(titles.contains("Ginásio Basic-Fit"))
        #expect(titles.contains("Renovar ginásio"))
        // Começa por "gin" vem antes de "contém" numa palavra a meio.
        #expect(titles.firstIndex(of: "Renovar ginásio")! > titles.firstIndex(of: "Ginásio")!)
        #expect(results.first { $0.title == "Ginásio" }?.target == .section(.habits))
    }

    @Test func findsSectionsAndNeedsTwoLetters() {
        let context = container.mainContext
        #expect(GlobalSearch.search("h", in: context).isEmpty)
        #expect(GlobalSearch.search("hábi", in: context).first?.target == .section(.habits))
    }

    @Test func transactionsOpenTheirForm() throws {
        let context = container.mainContext
        let transaction = FinanceTransaction(title: "Netflix", amount: 12.99, kind: .expense)
        context.insert(transaction)
        try context.save()
        #expect(GlobalSearch.search("netf", in: context).first?.target == .transaction(transaction.persistentModelID))
    }
}

@MainActor
struct AppRouterTests {
    @Test func opensSectionsInTabsAndSidebar() {
        let router = AppRouter()
        router.open(.habits)
        #expect(router.selection == .habits)

        router.usesTabs = true
        router.open(.habits)
        #expect(router.selection == nil)
        #expect(router.morePath == [.habits])
        router.open(.finance)
        #expect(router.selection == .finance)
    }
}
