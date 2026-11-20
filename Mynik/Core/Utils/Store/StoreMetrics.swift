import Foundation

/// Período dos KPIs da loja, sempre a terminar hoje.
nonisolated enum StorePeriod: String, CaseIterable, Identifiable, Sendable {
    case today
    case week
    case month

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Hoje"
        case .week: "7 dias"
        case .month: "30 dias"
        }
    }

    var comparisonTitle: String {
        switch self {
        case .today: "vs ontem"
        case .week: "vs 7 dias antes"
        case .month: "vs 30 dias antes"
        }
    }

    var days: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }

    /// Dias inteiros do período: de há `days - 1` dias até ao fim de hoje.
    func interval(endingAt now: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return DateInterval(start: start, end: end)
    }

    /// O período imediatamente anterior, com o mesmo número de dias.
    func previousInterval(endingAt now: Date, calendar: Calendar) -> DateInterval {
        let current = interval(endingAt: now, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -days, to: current.start) ?? current.start
        return DateInterval(start: start, end: current.start)
    }
}

/// Do que se vende ao que fica no bolso.
nonisolated struct ProfitBreakdown: Equatable, Sendable {
    /// Total pago pelos clientes (com IVA e envio, sem devoluções).
    var grossSales: Decimal = 0
    var vat: Decimal = 0
    var productCosts: Decimal = 0
    var shippingCosts: Decimal = 0
    var paymentFees: Decimal = 0
    var adSpend: Decimal = 0

    var netRevenue: Decimal { grossSales - vat }

    /// Lucro real: receita sem IVA − artigos − envio − taxas − anúncios.
    var profit: Decimal { netRevenue - productCosts - shippingCosts - paymentFees - adSpend }

    /// Margem sobre a receita sem IVA (`nil` sem receita).
    var margin: Double? {
        netRevenue > 0 ? (profit / netRevenue).doubleValue : nil
    }
}

/// Os números de um período e do anterior, para comparar.
struct StoreKPIs: Equatable {
    struct Values: Equatable {
        var orders = 0
        var units = 0
        var breakdown = ProfitBreakdown()
        var sessions = 0
        var completedSessions = 0
        var hasTraffic = false

        var sales: Decimal { breakdown.grossSales }
        var profit: Decimal { breakdown.profit }

        var averageOrderValue: Decimal? {
            orders > 0 ? breakdown.grossSales / Decimal(orders) : nil
        }

        /// Pedidos por visita (`nil` sem dados de tráfego).
        var conversionRate: Double? {
            hasTraffic && sessions > 0 ? Double(completedSessions) / Double(sessions) : nil
        }
    }

    var current: Values
    var previous: Values

    /// Variação relativa (0,1 = +10 %), ou `nil` se não há base de comparação.
    static func change(_ current: Decimal, _ previous: Decimal) -> Double? {
        guard previous != 0 else { return nil }
        return ((current - previous) / abs(previous)).doubleValue
    }

    static func change(_ current: Double?, _ previous: Double?) -> Double? {
        guard let current, let previous, previous != 0 else { return nil }
        return (current - previous) / abs(previous)
    }
}

/// Um ponto do gráfico diário.
struct StoreDailyPoint: Identifiable, Equatable {
    var date: Date
    var sales: Decimal
    var profit: Decimal

    var id: Date { date }
}

/// Calcula KPIs, lucro real e séries diárias a partir da cache.
struct StoreMetrics {
    let orders: [StoreOrder]
    let stats: [DailyStat]
    let products: [StoreProduct]
    let costs: StoreCostSettings
    var calendar: Calendar = .current

    private var unitCostByProduct: [String: Decimal] {
        Dictionary(products.map { ($0.shopifyID, $0.unitCost) }, uniquingKeysWith: { first, _ in first })
    }

    /// Anúncios por dia: gasto atribuído aos produtos + gerais, a dividir por 30.
    var dailyAdSpend: Decimal {
        let perProduct = products.reduce(Decimal(0)) { $0 + $1.adSpend30d }
        return (perProduct + costs.monthlyAds) / 30
    }

    func kpis(for period: StorePeriod, now: Date = .now) -> StoreKPIs {
        StoreKPIs(
            current: values(in: period.interval(endingAt: now, calendar: calendar)),
            previous: values(in: period.previousInterval(endingAt: now, calendar: calendar))
        )
    }

    func values(in interval: DateInterval) -> StoreKPIs.Values {
        let periodOrders = orders.filter { !$0.isCancelled && interval.contains($0.createdAt) && $0.createdAt < interval.end }
        let periodStats = stats.filter { $0.date >= interval.start && $0.date < interval.end }

        var values = StoreKPIs.Values()
        values.orders = periodOrders.count
        values.units = periodOrders.reduce(0) { $0 + $1.unitCount }
        values.breakdown = breakdown(for: periodOrders, days: dayCount(interval))
        values.hasTraffic = periodStats.contains(where: \.hasTraffic)
        values.sessions = periodStats.reduce(0) { $0 + $1.sessions }
        values.completedSessions = periodStats.reduce(0) { $0 + $1.completedSessions }
        return values
    }

    /// Lucro real de um conjunto de pedidos, com `days` dias de anúncios.
    func breakdown(for orders: [StoreOrder], days: Int) -> ProfitBreakdown {
        let costByProduct = unitCostByProduct
        var result = ProfitBreakdown()
        for order in orders where !order.isCancelled {
            result.grossSales += order.total
            result.vat += order.tax
            result.paymentFees += costs.paymentFee(for: order.total)
            if order.unitCount > 0 {
                result.shippingCosts += costs.shippingCost
            }
            for line in order.lines {
                result.productCosts += (costByProduct[line.productID] ?? 0) * Decimal(line.currentQuantity)
            }
        }
        result.adSpend = dailyAdSpend * Decimal(days)
        return result
    }

    /// Vendas e lucro de cada um dos últimos `days` dias (o mais antigo primeiro).
    func dailyPoints(days: Int = 30, now: Date = .now) -> [StoreDailyPoint] {
        let today = calendar.startOfDay(for: now)
        let ordersByDay = Dictionary(grouping: orders.filter { !$0.isCancelled }) { calendar.startOfDay(for: $0.createdAt) }

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let breakdown = breakdown(for: ordersByDay[day] ?? [], days: 1)
            return StoreDailyPoint(date: day, sales: breakdown.grossSales, profit: breakdown.profit)
        }
    }

    /// Produtos vendidos sem custo definido (o lucro fica sobrestimado).
    var productsMissingCost: [StoreProduct] {
        let sold = Set(orders.flatMap { $0.lines.map(\.productID) })
        return products.filter { $0.unitCost == 0 && sold.contains($0.shopifyID) }
    }

    private func dayCount(_ interval: DateInterval) -> Int {
        max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
    }
}
