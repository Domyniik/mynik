import Foundation
import Testing
@testable import Mynik

@MainActor
struct StoreAlertsTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now: Date

    init() {
        now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15)) ?? .now
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now) ?? now
    }

    private func order(_ name: String, daysAgo days: Int, product: String = "p1", fulfillment: String = "FULFILLED") -> StoreOrder {
        StoreOrder(shopifyID: name, name: name, createdAt: daysAgo(days), total: 20, fulfillmentStatus: fulfillment,
                   lines: [StoreOrderLine(productID: product, title: "Produto \(product)", quantity: 1, currentQuantity: 1, unitPrice: 20)])
    }

    private func product(_ id: String, age: Int, inventory: Int = 100) -> StoreProduct {
        StoreProduct(shopifyID: id, title: "Produto \(id)", price: 20, unitCost: 5, inventory: inventory, createdAt: daysAgo(age))
    }

    @Test func storeWithoutSalesForDaysRaisesAlert() {
        let alerts = StoreAlerts.make(products: [], orders: [order("#1", daysAgo: 4)], noSaleDays: 3, now: now, calendar: calendar)
        #expect(alerts.map(\.kind) == [.noSales])
        #expect(alerts.first?.title == "4 dias sem venda")
        #expect(alerts.first?.isCritical == false)

        let critical = StoreAlerts.make(products: [], orders: [order("#1", daysAgo: 7)], noSaleDays: 3, now: now, calendar: calendar)
        #expect(critical.first?.isCritical == true)

        #expect(StoreAlerts.make(products: [], orders: [order("#1", daysAgo: 1)], noSaleDays: 3, now: now, calendar: calendar).isEmpty)
        #expect(StoreAlerts.daysWithoutSales(orders: [], now: now, calendar: calendar) == nil)
    }

    @Test func staleProductsLateOrdersAndLowStock() {
        let products = [product("p1", age: 60), product("p2", age: 60), product("p3", age: 5), product("p4", age: 30, inventory: 2)]
        let orders = [
            order("#1", daysAgo: 0, product: "p1"),
            order("#2", daysAgo: 20, product: "p2"),
            order("#3", daysAgo: 6, product: "p1", fulfillment: "UNFULFILLED"),
        ] + (0..<15).map { order("#p4-\($0)", daysAgo: $0, product: "p4") }

        let alerts = StoreAlerts.make(products: products, orders: orders, now: now, calendar: calendar)
        let ids = Set(alerts.map(\.id))

        #expect(ids.contains("productStale-p2"))
        #expect(!ids.contains("productStale-p3"), "Produto novo ainda não gera alerta")
        #expect(ids.contains("lateOrders-"))
        #expect(ids.contains("lowStock-p4"))
        #expect(alerts.first?.isCritical == true, "Críticos primeiro")
    }

    @Test func saleNotificationTextListsItems() {
        let sale = StoreNotifier.Sale(orderID: "o1", name: "#1023", total: Decimal(string: "39.9")!, itemTitles: ["Colar Lua", "Brincos", "Anel"])
        let content = StoreNotifier.content(for: sale)
        #expect(content.title == "Nova venda #1023 · \(Currency.format(Decimal(string: "39.9")!))")
        #expect(content.body == "Colar Lua, Brincos…")
    }

    @Test func newOrdersCarryShopifyID() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let since = daysAgo(59)
        func record(_ id: String) -> StoreSnapshot.OrderRecord {
            .init(id: id, name: "#\(id)", createdAt: now, cancelledAt: nil, subtotal: 10, shipping: 0, tax: 0, total: 10,
                  refunded: 0, currencyCode: "EUR", financialStatus: "PAID", fulfillmentStatus: "UNFULFILLED", lines: [])
        }
        func snapshot(_ orders: [StoreSnapshot.OrderRecord]) -> StoreSnapshot {
            StoreSnapshot(shopName: "T", products: [], orders: orders, traffic: [], trafficUnavailableReason: nil)
        }
        try StoreCacheWriter.apply(snapshot([record("1")]), since: since, to: container.mainContext, now: now, calendar: calendar)
        let result = try StoreCacheWriter.apply(snapshot([record("1"), record("2")]), since: since, to: container.mainContext, now: now, calendar: calendar)
        #expect(result.newOrders.map(\.id) == ["2"])
    }
}
