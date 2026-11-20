import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct StoreCacheTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar(identifier: .gregorian)
    private let now: Date
    private let since: Date

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15)) ?? .now
        since = calendar.date(byAdding: .day, value: -59, to: calendar.startOfDay(for: now)) ?? now
    }

    private func product(_ id: String, title: String = "Colar", cost: Decimal? = 5) -> StoreSnapshot.ProductRecord {
        .init(id: id, title: title, handle: "", status: "ACTIVE", imageURL: "", price: 20, unitCost: cost,
              inventory: 10, tracksInventory: true, createdAt: since)
    }

    private func order(_ id: String, daysAgo: Int, total: Decimal = 24.60, quantity: Int = 1) -> StoreSnapshot.OrderRecord {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return .init(id: id, name: "#\(id)", createdAt: date, cancelledAt: nil, subtotal: total, shipping: 0,
                     tax: 4.60, total: total, refunded: 0, currencyCode: "EUR", financialStatus: "PAID",
                     fulfillmentStatus: "FULFILLED",
                     lines: [StoreOrderLine(productID: "p1", title: "Colar", quantity: quantity, currentQuantity: quantity, unitPrice: 20)])
    }

    private func snapshot(products: [StoreSnapshot.ProductRecord], orders: [StoreSnapshot.OrderRecord],
                          traffic: [StoreSnapshot.TrafficRecord] = []) -> StoreSnapshot {
        StoreSnapshot(shopName: "Teste", products: products, orders: orders, traffic: traffic, trafficUnavailableReason: nil)
    }

    @Test func upsertsProductsKeepingManualFields() throws {
        try StoreCacheWriter.apply(snapshot(products: [product("p1"), product("p2")], orders: []), since: since, to: context, now: now, calendar: calendar)

        let colar = try #require(try context.fetch(FetchDescriptor<StoreProduct>()).first { $0.shopifyID == "p1" })
        colar.unitCost = 7
        colar.unitCostIsManual = true
        colar.adSpend30d = 50

        try StoreCacheWriter.apply(snapshot(products: [product("p1", title: "Colar Lua", cost: 3)], orders: []), since: since, to: context, now: now, calendar: calendar)

        let products = try context.fetch(FetchDescriptor<StoreProduct>())
        #expect(products.count == 1)
        #expect(products.first?.title == "Colar Lua")
        #expect(products.first?.unitCost == 7)
        #expect(products.first?.adSpend30d == 50)
    }

    @Test func reportsOnlyOrdersNewSinceLastSync() throws {
        let first = try StoreCacheWriter.apply(snapshot(products: [], orders: [order("1", daysAgo: 2)]), since: since, to: context, now: now, calendar: calendar)
        #expect(first.newOrders.isEmpty)

        let second = try StoreCacheWriter.apply(
            snapshot(products: [], orders: [order("1", daysAgo: 2), order("2", daysAgo: 0, total: 30)]),
            since: since, to: context, now: now, calendar: calendar
        )
        #expect(second.newOrders.map(\.name) == ["#2"])
        #expect(second.newOrders.first?.total == 30)
        #expect(try context.fetchCount(FetchDescriptor<StoreOrder>()) == 2)
    }

    @Test func rebuildsDailyStatsWithTraffic() throws {
        let today = calendar.startOfDay(for: now)
        let traffic = StoreSnapshot.TrafficRecord(day: today, sessions: 100, cartSessions: 8, checkoutSessions: 5, completedSessions: 2)
        try StoreCacheWriter.apply(
            snapshot(products: [], orders: [order("1", daysAgo: 0), order("2", daysAgo: 0, quantity: 2), order("3", daysAgo: 1)], traffic: [traffic]),
            since: since, to: context, now: now, calendar: calendar
        )

        let stats = try context.fetch(FetchDescriptor<DailyStat>(sortBy: [SortDescriptor(\.date)]))
        #expect(stats.count == 60)
        let todayStat = try #require(stats.last)
        #expect(todayStat.date == today)
        #expect(todayStat.orders == 2)
        #expect(todayStat.units == 3)
        #expect(todayStat.sales == Decimal(string: "49.2"))
        #expect(todayStat.netRevenue == 40)
        #expect(todayStat.sessions == 100)
        #expect(todayStat.hasTraffic)
        #expect(stats[stats.count - 2].orders == 1)
        #expect(stats[stats.count - 2].hasTraffic == false)
    }

    @Test func demoStoreIsDeterministicAndCoversWindow() async throws {
        let demo = DemoStoreDataSource(now: now, calendar: calendar)
        let first = try await demo.fetchSnapshot(since: since)
        let second = try await demo.fetchSnapshot(since: since)

        #expect(first.orders == second.orders)
        #expect(first.traffic.count == 60)
        #expect(first.products.count == 8)
        #expect(first.orders.allSatisfy { $0.createdAt >= since && $0.createdAt <= now })
        #expect(first.orders.contains { calendar.isDate($0.createdAt, inSameDayAs: now) })
        // Totais em cêntimos exatos e IVA incluído coerente.
        #expect(first.orders.allSatisfy { $0.total == $0.subtotal + $0.shipping })
    }

    @Test func removeAllClearsStoreCache() throws {
        try StoreCacheWriter.apply(snapshot(products: [product("p1")], orders: [order("1", daysAgo: 1)]), since: since, to: context, now: now, calendar: calendar)
        try StoreCacheWriter.removeAll(from: context)
        #expect(try context.fetchCount(FetchDescriptor<StoreProduct>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<StoreOrder>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<DailyStat>()) == 0)
    }
}

/// Uma base de dados criada pela v0.2 (esquema V1) abre na versão atual sem perder dados.
@MainActor
struct SchemaMigrationTests {
    @Test func migratesVersionOneStoreOnDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "mynik-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")

        do {
            let schema = Schema(versionedSchema: MynikSchemaV1.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let transaction = MynikSchemaV1.FinanceTransaction()
            transaction.title = "Renda"
            transaction.amount = 750
            old.mainContext.insert(transaction)
            try old.mainContext.save()
        }

        let current = try ModelContainerFactory.make(url: url)
        let transactions = try current.mainContext.fetch(FetchDescriptor<FinanceTransaction>())
        #expect(transactions.map(\.title) == ["Renda"])
        #expect(transactions.first?.amount == 750)
        #expect(try current.mainContext.fetchCount(FetchDescriptor<StoreProduct>()) == 0)
    }
}

struct ShopifyStoreDataSourceTests {
    @Test func decodesProductsOrdersAndTraffic() async throws {
        let products = """
        {"data":{"products":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[
          {"id":"gid://shopify/Product/1","title":"Colar Lua","handle":"colar-lua","status":"ACTIVE",
           "createdAt":"2026-09-01T10:00:00Z","totalInventory":12,"tracksInventory":true,
           "featuredMedia":{"preview":{"image":{"url":"https://cdn.shopify.com/colar.jpg"}}},
           "priceRangeV2":{"minVariantPrice":{"amount":"29.9"}},
           "variants":{"nodes":[{"inventoryItem":{"unitCost":{"amount":"7.5"}}}]}}]}}}
        """
        let orders = """
        {"data":{"orders":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[
          {"id":"gid://shopify/Order/1","name":"#1001","createdAt":"2026-11-19T18:30:00Z","cancelledAt":null,
           "test":false,"currencyCode":"EUR","displayFinancialStatus":"PAID","displayFulfillmentStatus":"UNFULFILLED",
           "currentSubtotalPriceSet":{"shopMoney":{"amount":"29.9"}},"currentShippingPriceSet":{"shopMoney":{"amount":"3.9"}},
           "currentTotalTaxSet":{"shopMoney":{"amount":"6.32"}},"currentTotalPriceSet":{"shopMoney":{"amount":"33.8"}},
           "totalRefundedSet":{"shopMoney":{"amount":"0.0"}},
           "lineItems":{"nodes":[{"title":"Colar Lua","quantity":1,"currentQuantity":1,
             "product":{"id":"gid://shopify/Product/1"},"originalUnitPriceSet":{"shopMoney":{"amount":"29.9"}}}]}},
          {"id":"gid://shopify/Order/2","name":"#1002","createdAt":"2026-11-19T19:00:00Z","cancelledAt":null,
           "test":true,"currencyCode":"EUR","displayFinancialStatus":"PAID","displayFulfillmentStatus":"UNFULFILLED",
           "currentSubtotalPriceSet":{"shopMoney":{"amount":"1"}},"currentShippingPriceSet":{"shopMoney":{"amount":"0"}},
           "currentTotalTaxSet":{"shopMoney":{"amount":"0"}},"currentTotalPriceSet":{"shopMoney":{"amount":"1"}},
           "totalRefundedSet":{"shopMoney":{"amount":"0"}},"lineItems":{"nodes":[]}}]}}}
        """
        let traffic = """
        {"data":{"shopifyqlQuery":{"parseErrors":[],"tableData":{"rows":[
          {"day":"2026-11-19","sessions":"120","sessions_with_cart_additions":9,
           "sessions_that_reached_checkout":5,"sessions_that_completed_checkout":2}]}}}}
        """
        let stub = StubTransport([.init(body: products), .init(body: orders), .init(body: traffic)])
        let client = ShopifyClient(
            credentials: ShopifyCredentials(shopDomain: "neloce.myshopify.com", auth: .accessToken("shpat_teste")),
            transport: { try await stub.handle($0) },
            sleep: { _ in }
        )
        let calendar = Calendar(identifier: .gregorian)
        let source = ShopifyStoreDataSource(client: client, calendar: calendar)
        let since = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22)) ?? .now

        let fetchedProducts = try await source.fetchProducts()
        let fetchedOrders = try await source.fetchOrders(since: since)
        let fetchedTraffic = try await source.fetchTraffic(since: since)

        #expect(fetchedProducts.first?.price == Decimal(string: "29.9"))
        #expect(fetchedProducts.first?.unitCost == Decimal(string: "7.5"))
        #expect(fetchedProducts.first?.imageURL == "https://cdn.shopify.com/colar.jpg")
        #expect(fetchedOrders.map(\.name) == ["#1001"], "Pedidos de teste são ignorados")
        #expect(fetchedOrders.first?.lines.first?.productID == "gid://shopify/Product/1")
        #expect(fetchedTraffic.first?.sessions == 120)
        #expect(fetchedTraffic.first?.day == calendar.date(from: DateComponents(year: 2026, month: 11, day: 19)))

        let ordersBody = try #require(await stub.requests[1].httpBody)
        #expect(String(decoding: ordersBody, as: UTF8.self).contains("created_at:>=2026-09-22"))
    }
}
