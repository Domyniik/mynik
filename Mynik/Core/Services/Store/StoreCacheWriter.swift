import Foundation
import SwiftData

/// Escreve uma `StoreSnapshot` na cache SwiftData.
///
/// Atualiza por ID da Shopify (sem `@Attribute(.unique)`, por causa do
/// CloudKit), mantém os campos manuais dos produtos e reconstrói os
/// `DailyStat` dos dias sincronizados.
enum StoreCacheWriter {
    /// Pedidos e estatísticas mais antigos do que isto são apagados.
    static let retentionDays = 120

    struct Result: Sendable, Equatable {
        var productCount: Int
        var orderCount: Int
        /// Pedidos que não existiam na cache (vazio na primeira sincronização).
        var newOrders: [NewOrder]
    }

    struct NewOrder: Sendable, Equatable {
        var name: String
        var total: Decimal
        var createdAt: Date
        var itemTitles: [String]
    }

    @discardableResult
    static func apply(
        _ snapshot: StoreSnapshot,
        since: Date,
        to context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> Result {
        let productCount = try applyProducts(snapshot.products, to: context, now: now)
        let newOrders = try applyOrders(snapshot.orders, since: since, to: context, now: now, calendar: calendar)
        try rebuildDailyStats(snapshot, since: since, in: context, now: now, calendar: calendar)
        try context.save()
        return Result(productCount: productCount, orderCount: snapshot.orders.count, newOrders: newOrders)
    }

    /// Apaga toda a cache da loja (ao trocar entre dados de exemplo e a loja real).
    static func removeAll(from context: ModelContext) throws {
        try context.delete(model: StoreOrder.self)
        try context.delete(model: StoreProduct.self)
        try context.delete(model: DailyStat.self)
        try context.save()
    }

    // MARK: - Produtos

    private static func applyProducts(
        _ records: [StoreSnapshot.ProductRecord],
        to context: ModelContext,
        now: Date
    ) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<StoreProduct>())
        let byID = Dictionary(existing.map { ($0.shopifyID, $0) }, uniquingKeysWith: { first, _ in first })

        for record in records {
            let product: StoreProduct
            if let current = byID[record.id] {
                product = current
            } else {
                product = StoreProduct(shopifyID: record.id, title: record.title)
                product.adSpend30d = record.adSpend30d ?? 0
                context.insert(product)
            }
            product.title = record.title
            product.handle = record.handle
            product.statusRaw = record.status
            product.imageURLString = record.imageURL
            product.price = record.price
            if !product.unitCostIsManual, let cost = record.unitCost {
                product.unitCost = cost
            }
            product.inventory = record.inventory
            product.tracksInventory = record.tracksInventory
            product.createdAt = record.createdAt
            product.syncedAt = now
        }

        // Produtos apagados na Shopify desaparecem da cache.
        let incoming = Set(records.map(\.id))
        for product in existing where !incoming.contains(product.shopifyID) {
            context.delete(product)
        }
        return records.count
    }

    // MARK: - Pedidos

    private static func applyOrders(
        _ records: [StoreSnapshot.OrderRecord],
        since: Date,
        to context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws -> [NewOrder] {
        let existing = try context.fetch(FetchDescriptor<StoreOrder>())
        let byID = Dictionary(existing.map { ($0.shopifyID, $0) }, uniquingKeysWith: { first, _ in first })
        let isFirstSync = existing.isEmpty
        var newOrders: [NewOrder] = []

        for record in records {
            let order: StoreOrder
            if let current = byID[record.id] {
                order = current
            } else {
                order = StoreOrder(shopifyID: record.id, name: record.name, createdAt: record.createdAt)
                context.insert(order)
                if !isFirstSync, record.cancelledAt == nil {
                    newOrders.append(NewOrder(
                        name: record.name,
                        total: record.total,
                        createdAt: record.createdAt,
                        itemTitles: record.lines.map(\.title)
                    ))
                }
            }
            order.name = record.name
            order.createdAt = record.createdAt
            order.cancelledAt = record.cancelledAt
            order.subtotal = record.subtotal
            order.shipping = record.shipping
            order.tax = record.tax
            order.total = record.total
            order.refunded = record.refunded
            order.currencyCode = record.currencyCode
            order.financialStatusRaw = record.financialStatus
            order.fulfillmentStatusRaw = record.fulfillmentStatus
            order.lines = record.lines
            order.syncedAt = now
        }

        // Dentro da janela, a Shopify é a fonte de verdade; fora dela, só a retenção.
        let incoming = Set(records.map(\.id))
        let cutoff = retentionCutoff(now: now, calendar: calendar)
        for order in existing where !incoming.contains(order.shopifyID) {
            if order.createdAt >= since || order.createdAt < cutoff {
                context.delete(order)
            }
        }
        return newOrders.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Estatísticas diárias

    private static func rebuildDailyStats(
        _ snapshot: StoreSnapshot,
        since: Date,
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws {
        let firstDay = calendar.startOfDay(for: since)
        let today = calendar.startOfDay(for: now)

        var stats: [Date: DailyStatValues] = [:]
        var day = firstDay
        while day <= today {
            stats[day] = DailyStatValues()
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        for order in snapshot.orders where order.cancelledAt == nil {
            let key = calendar.startOfDay(for: order.createdAt)
            guard stats[key] != nil else { continue }
            stats[key]?.sales += order.total
            stats[key]?.netRevenue += order.total - order.tax
            stats[key]?.orders += 1
            stats[key]?.units += order.lines.reduce(0) { $0 + $1.currentQuantity }
            stats[key]?.refunds += order.refunded
        }
        for traffic in snapshot.traffic {
            let key = calendar.startOfDay(for: traffic.day)
            guard stats[key] != nil else { continue }
            stats[key]?.traffic = traffic
        }

        let existing = try context.fetch(FetchDescriptor<DailyStat>())
        let byDay = Dictionary(existing.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { first, _ in first })
        for (day, values) in stats {
            let stat = byDay[day] ?? {
                let stat = DailyStat(date: day)
                context.insert(stat)
                return stat
            }()
            values.write(to: stat)
        }

        let cutoff = retentionCutoff(now: now, calendar: calendar)
        for stat in existing where stat.date < cutoff {
            context.delete(stat)
        }
    }

    private static func retentionCutoff(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -retentionDays, to: calendar.startOfDay(for: now)) ?? .distantPast
    }
}

/// Valores de um dia enquanto são somados.
private struct DailyStatValues {
    var sales: Decimal = 0
    var netRevenue: Decimal = 0
    var orders = 0
    var units = 0
    var refunds: Decimal = 0
    var traffic: StoreSnapshot.TrafficRecord?

    func write(to stat: DailyStat) {
        stat.sales = sales
        stat.netRevenue = netRevenue
        stat.orders = orders
        stat.units = units
        stat.refunds = refunds
        stat.hasTraffic = traffic != nil
        stat.sessions = traffic?.sessions ?? 0
        stat.cartSessions = traffic?.cartSessions ?? 0
        stat.checkoutSessions = traffic?.checkoutSessions ?? 0
        stat.completedSessions = traffic?.completedSessions ?? 0
    }
}
