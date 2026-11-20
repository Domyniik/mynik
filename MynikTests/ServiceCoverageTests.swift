import Foundation
import SwiftData
import Testing
@testable import Mynik

/// As ferramentas que o modelo de linguagem chama, executadas sem o modelo.
@MainActor
struct MynikToolsTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }

    @Test func financeToolSummarizesOrFilters() async throws {
        let context = container.mainContext
        context.insert(FinanceTransaction(title: "Mercadona", amount: 30, kind: .expense))
        context.insert(FinanceTransaction(title: "Repsol", amount: 50, kind: .expense))
        try context.save()

        let tool = FinanceTool(container: container, converter: CurrencyConverter())
        let summary = try await tool.call(arguments: .init(mesesAtras: 0, filtro: " "))
        #expect(summary.contains("Gastos: 80,00"))
        let filtered = try await tool.call(arguments: .init(mesesAtras: 0, filtro: "mercadona"))
        #expect(filtered.contains("30,00"))
        #expect(!filtered.contains("80,00"))
    }

    @Test func billsAndLifeTools() async throws {
        let context = container.mainContext
        context.insert(Bill(title: "Internet", amount: 35, dueDate: .now))
        context.insert(Goal(title: "Viagem", targetAmount: 1000))
        try context.save()

        let bills = try await BillsTool(container: container, converter: CurrencyConverter()).call(arguments: .init(dias: 7))
        #expect(bills.contains("Internet"))

        let life = LifeTool(container: container, converter: CurrencyConverter())
        #expect(try await life.call(arguments: .init(tema: "metas")).contains("Viagem"))
        // Tema desconhecido cai na agenda geral, sem falhar.
        #expect(try await life.call(arguments: .init(tema: "xpto")).contains("prazos"))
    }

    @Test func storeToolReadsTheDemoStore() async throws {
        let defaults = try #require(UserDefaults(suiteName: "tools-\(UUID().uuidString)"))
        let coordinator = StoreSyncCoordinator(defaults: defaults)
        await coordinator.refresh(in: container.mainContext)

        let text = try await StoreTool(container: container, converter: CurrencyConverter()).call(arguments: .init(periodo: "30 dias"))
        #expect(text.hasPrefix("Loja — 30 dias"))
        #expect(text.contains("Pedidos:"))
    }
}

/// Sincronização da loja com os dados de exemplo (sem rede).
@MainActor
struct StoreSyncCoordinatorTests {
    @Test func demoRefreshFillsCacheAndRespectsInterval() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let defaults = try #require(UserDefaults(suiteName: "sync-\(UUID().uuidString)"))
        let coordinator = StoreSyncCoordinator(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        await coordinator.refreshIfStale(in: context, now: now)
        #expect(coordinator.isDemo)
        #expect(coordinator.lastSyncedAt == now)
        #expect(coordinator.lastError == nil)
        #expect(try context.fetchCount(FetchDescriptor<DailyStat>()) > 0)
        #expect(try context.fetchCount(FetchDescriptor<StoreOrder>()) > 0)

        // Dentro do intervalo mínimo não volta a sincronizar.
        await coordinator.refreshIfStale(in: context, now: now.addingTimeInterval(60))
        #expect(coordinator.lastSyncedAt == now)

        let later = now.addingTimeInterval(StoreSyncCoordinator.minimumInterval)
        await coordinator.refreshIfStale(in: context, now: later)
        #expect(coordinator.lastSyncedAt == later)
    }
}

@MainActor
struct ApplePayCategorizationTests {
    @Test func newMerchantUsesMerchantRules() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try DefaultDataSeeder.seedIfNeeded(in: context)
        let outcome = try ApplePayEntry.register(merchant: "MERCADONA MADRID", amountText: "23,10 €", card: "Visa", in: context)
        #expect(outcome.transaction.category?.name == "Alimentação")
        #expect(outcome.transaction.notes == "Apple Pay · Visa")
    }
}

/// Invariantes da navegação e da paleta.
struct AppInvariantTests {
    @Test func sectionsHaveUniqueTitlesAndSymbols() {
        let sections = AppSection.allCases
        #expect(Set(sections.map(\.title)).count == sections.count)
        #expect(Set(sections.map(\.symbolName)).count == sections.count)
        #expect(Set(AppSection.primaryTabs).isSubset(of: sections))
        #expect(AppSection.moreTabs.count + AppSection.primaryTabs.count == sections.count)
    }

    @Test func colorsHaveUniquePortugueseNames() {
        let names = CategoryColor.allCases.map(\.name)
        #expect(Set(names).count == names.count)
        #expect(!names.contains { $0.isEmpty })
    }

    @Test func lifeTopicsRoundTripThroughRawValues() {
        for topic in LifeTopic.allCases {
            #expect(LifeTopic(rawValue: topic.rawValue) == topic)
        }
    }
}
