import Foundation
import Testing
@testable import Mynik

@MainActor
struct StoreMetricsTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now: Date
    private let costs = StoreCostSettings(paymentFeePercent: 2, paymentFeeFixed: 0.3, shippingCostPerOrder: 4, monthlyAdSpend: 30)

    init() {
        now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15)) ?? .now
    }

    private func date(daysAgo: Int, hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func order(_ name: String, daysAgo: Int, quantity: Int = 1, cancelled: Bool = false) -> StoreOrder {
        let total = Decimal(string: "24.6")! * Decimal(quantity)
        let order = StoreOrder(
            shopifyID: name, name: name, createdAt: date(daysAgo: daysAgo),
            subtotal: total, tax: Decimal(string: "4.6")! * Decimal(quantity), total: total,
            lines: [StoreOrderLine(productID: "p1", title: "Colar", quantity: quantity, currentQuantity: quantity, unitPrice: 24.6)]
        )
        if cancelled { order.cancelledAt = order.createdAt }
        return order
    }

    private func metrics(_ orders: [StoreOrder], stats: [DailyStat] = []) -> StoreMetrics {
        StoreMetrics(
            orders: orders,
            stats: stats,
            products: [StoreProduct(shopifyID: "p1", title: "Colar", price: 24.6, unitCost: 5)],
            costs: costs,
            calendar: calendar
        )
    }

    @Test func profitSubtractsVATCostsShippingFeesAndAds() {
        let breakdown = metrics([order("#1", daysAgo: 0)]).breakdown(for: [order("#1", daysAgo: 0)], days: 1)

        #expect(breakdown.grossSales == Decimal(string: "24.6"))
        #expect(breakdown.netRevenue == 20)
        #expect(breakdown.productCosts == 5)
        #expect(breakdown.shippingCosts == 4)
        #expect(breakdown.paymentFees == Decimal(string: "0.792"))
        #expect(breakdown.adSpend == 1)
        #expect(breakdown.profit == Decimal(string: "9.208"))
        #expect(abs((breakdown.margin ?? 0) - 0.4604) < 0.0001)
    }

    @Test func comparesTodayWithYesterdayAndIgnoresCancelled() {
        let orders = [
            order("#1", daysAgo: 0, quantity: 2),
            order("#2", daysAgo: 0),
            order("#3", daysAgo: 0, cancelled: true),
            order("#4", daysAgo: 1),
        ]
        let kpis = metrics(orders).kpis(for: .today, now: now)

        #expect(kpis.current.orders == 2)
        #expect(kpis.current.units == 3)
        #expect(kpis.current.sales == Decimal(string: "73.8"))
        #expect(kpis.current.averageOrderValue == Decimal(string: "36.9"))
        #expect(kpis.previous.orders == 1)
        #expect(StoreKPIs.change(kpis.current.sales, kpis.previous.sales) == 2)
    }

    @Test func weekIncludesSevenFullDays() {
        let orders = [order("#1", daysAgo: 6), order("#2", daysAgo: 7), order("#3", daysAgo: 13), order("#4", daysAgo: 14)]
        let kpis = metrics(orders).kpis(for: .week, now: now)
        #expect(kpis.current.orders == 1)
        #expect(kpis.previous.orders == 2)
        #expect(kpis.current.breakdown.adSpend == 7)
    }

    @Test func conversionNeedsTrafficData() {
        let today = calendar.startOfDay(for: now)
        let stat = DailyStat(date: today)
        stat.sessions = 200
        stat.completedSessions = 5
        stat.hasTraffic = true

        let withTraffic = metrics([order("#1", daysAgo: 0)], stats: [stat]).kpis(for: .today, now: now)
        #expect(withTraffic.current.conversionRate == 0.025)

        let without = metrics([order("#1", daysAgo: 0)]).kpis(for: .today, now: now)
        #expect(without.current.conversionRate == nil)
    }

    @Test func dailyPointsCoverEveryDayOldestFirst() {
        let points = metrics([order("#1", daysAgo: 0), order("#2", daysAgo: 2), order("#3", daysAgo: 2)]).dailyPoints(days: 30, now: now)

        #expect(points.count == 30)
        #expect(points.last?.date == calendar.startOfDay(for: now))
        #expect(points.last?.sales == Decimal(string: "24.6"))
        #expect(points[27].sales == Decimal(string: "49.2"))
        // Dia sem vendas: só anúncios, lucro negativo.
        #expect(points[28].profit == -1)
    }

    @Test func flagsSoldProductsWithoutCost() {
        let products = [StoreProduct(shopifyID: "p1", title: "Colar"), StoreProduct(shopifyID: "p2", title: "Anel")]
        let metrics = StoreMetrics(orders: [order("#1", daysAgo: 0)], stats: [], products: products, costs: costs, calendar: calendar)
        #expect(metrics.productsMissingCost.map(\.title) == ["Colar"])
    }
}
