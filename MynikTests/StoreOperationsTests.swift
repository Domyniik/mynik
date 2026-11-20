import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct StoreOperationsTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now: Date

    init() {
        now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15)) ?? .now
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now) ?? now
    }

    private func order(_ name: String, daysAgo days: Int, fulfillment: String, financial: String = "PAID", units: Int = 1) -> StoreOrder {
        StoreOrder(
            shopifyID: name, name: name, createdAt: daysAgo(days), total: 20,
            financialStatus: financial, fulfillmentStatus: fulfillment,
            lines: [StoreOrderLine(productID: "p1", title: "Colar", quantity: 1, currentQuantity: units, unitPrice: 20)]
        )
    }

    @Test func listsPendingOrdersOldestFirstAndFlagsLateOnes() {
        let cancelled = order("#5", daysAgo: 1, fulfillment: "UNFULFILLED")
        cancelled.cancelledAt = daysAgo(1)
        let orders = [
            order("#1", daysAgo: 0, fulfillment: "UNFULFILLED"),
            order("#2", daysAgo: 5, fulfillment: "PARTIALLY_FULFILLED"),
            order("#3", daysAgo: 2, fulfillment: "FULFILLED"),
            order("#4", daysAgo: 1, fulfillment: "UNFULFILLED", financial: "REFUNDED", units: 0),
            cancelled,
        ]

        let pending = StoreOperations.ordersToShip(orders, now: now, calendar: calendar)

        #expect(pending.map(\.order.name) == ["#2", "#1"])
        #expect(pending.map(\.daysWaiting) == [5, 0])
        #expect(pending.map(\.isLate) == [true, false])
    }

    @Test func countsAbandonedUnitsPerProductInWindow() {
        let checkouts = [
            StoreCheckout(shopifyID: "c1", name: "#C1", createdAt: daysAgo(1), total: 30,
                          lines: [StoreCheckoutLine(productID: "p1", title: "Colar", quantity: 2)]),
            StoreCheckout(shopifyID: "c2", name: "#C2", createdAt: daysAgo(3), total: 30,
                          lines: [StoreCheckoutLine(productID: "p1", title: "Colar", quantity: 1),
                                  StoreCheckoutLine(productID: "p2", title: "Anel", quantity: 1)]),
            StoreCheckout(shopifyID: "c3", name: "#C3", createdAt: daysAgo(40), total: 30,
                          lines: [StoreCheckoutLine(productID: "p2", title: "Anel", quantity: 5)]),
        ]

        let units = StoreOperations.abandonedUnitsByProduct(checkouts, now: now, calendar: calendar)
        #expect(units == ["p1": 3, "p2": 1])
        #expect(StoreOperations.abandonedUnitsByProduct([], now: now, calendar: calendar) == nil)
        #expect(StoreOperations.recentCheckouts(checkouts, days: 7, now: now, calendar: calendar).map(\.name) == ["#C1", "#C2"])
    }

    @Test func cacheReplacesRecoveredCheckouts() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let since = daysAgo(59)
        func snapshot(_ checkouts: [StoreSnapshot.CheckoutRecord]) -> StoreSnapshot {
            StoreSnapshot(shopName: "Teste", products: [], orders: [], traffic: [], trafficUnavailableReason: nil, checkouts: checkouts)
        }
        let first = StoreSnapshot.CheckoutRecord(id: "c1", name: "#C1", createdAt: daysAgo(1), total: 30, recoveryURL: "https://neloce.myshopify.com/r/1", lines: [])
        let second = StoreSnapshot.CheckoutRecord(id: "c2", name: "#C2", createdAt: daysAgo(0), total: 15, recoveryURL: "", lines: [])

        try StoreCacheWriter.apply(snapshot([first, second]), since: since, to: context, now: now, calendar: calendar)
        try StoreCacheWriter.apply(snapshot([second]), since: since, to: context, now: now, calendar: calendar)

        let cached = try context.fetch(FetchDescriptor<StoreCheckout>())
        #expect(cached.map(\.name) == ["#C2"])
        #expect(cached.first?.recoveryURL == nil)
    }

    @Test func demoStoreHasPendingOrdersAndAbandonedCheckouts() async throws {
        let since = daysAgo(59)
        let snapshot = try await DemoStoreDataSource(now: now, calendar: calendar).fetchSnapshot(since: since)
        #expect(!snapshot.checkouts.isEmpty)
        #expect(snapshot.checkouts.allSatisfy { $0.createdAt <= now })
        #expect(snapshot.orders.contains { $0.fulfillmentStatus == "UNFULFILLED" })
    }
}
