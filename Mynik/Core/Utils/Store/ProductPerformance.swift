import Foundation

/// Desempenho de um produto nos últimos 30 dias, a base do ranking.
nonisolated struct ProductPerformance: Sendable, Equatable, Identifiable {
    var productID: String
    var title: String
    var price: Decimal
    var unitCost: Decimal
    /// Dias desde que o produto foi criado na loja.
    var ageDays: Int
    /// Unidades vendidas e mantidas (sem devoluções).
    var units: Int
    /// Unidades encomendadas (antes de devoluções).
    var orderedUnits: Int
    var refundedUnits: Int
    /// Receita dos artigos, já sem devoluções.
    var revenue: Decimal
    /// `nil` quando não vendeu nada na janela sincronizada.
    var daysSinceLastSale: Int?
    var adSpend: Decimal
    var inventory: Int
    var tracksInventory: Bool
    /// Unidades deixadas em checkouts abandonados (funil checkout → compra).
    /// `nil` quando não há dados de checkouts abandonados.
    var abandonedUnits: Int? = nil

    var id: String { productID }

    static let windowDays = 30

    /// Margem bruta por unidade sobre o preço (0,6 = 60 %).
    var marginRate: Double? {
        price > 0 ? ((price - unitCost) / price).doubleValue : nil
    }

    var refundRate: Double {
        orderedUnits > 0 ? Double(refundedUnits) / Double(orderedUnits) : 0
    }

    /// Receita por cada euro em anúncios (`nil` sem anúncios).
    var roas: Double? {
        adSpend > 0 ? (revenue / adSpend).doubleValue : nil
    }

    /// Das unidades que chegaram ao checkout, quantas foram compradas.
    /// `nil` com menos de 5 unidades (poucos dados).
    var checkoutConversion: Double? {
        guard let abandonedUnits else { return nil }
        let reached = orderedUnits + abandonedUnits
        return reached >= 5 ? Double(orderedUnits) / Double(reached) : nil
    }

    /// Dias de stock ao ritmo atual de vendas (`nil` se não há vendas ou não conta stock).
    var daysOfStock: Int? {
        guard tracksInventory, units > 0 else { return nil }
        return Int((Double(max(0, inventory)) / (Double(units) / Double(Self.windowDays))).rounded(.down))
    }
}

extension ProductPerformance {
    /// Calcula o desempenho dos produtos ativos a partir da cache.
    static func build(
        products: [StoreProduct],
        orders: [StoreOrder],
        abandonedUnitsByProduct: [String: Int]? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ProductPerformance] {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        let recentOrders = orders.filter { !$0.isCancelled && $0.createdAt >= windowStart }

        // Última venda em toda a cache (pode ser anterior à janela de 30 dias).
        var lastSale: [String: Date] = [:]
        for order in orders where !order.isCancelled {
            for line in order.lines where line.currentQuantity > 0 {
                lastSale[line.productID] = max(lastSale[line.productID] ?? .distantPast, order.createdAt)
            }
        }

        return products.filter(\.isActive).map { product in
            var performance = ProductPerformance(
                productID: product.shopifyID,
                title: product.title,
                price: product.price,
                unitCost: product.unitCost,
                ageDays: max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: product.createdAt), to: today).day ?? 0),
                units: 0,
                orderedUnits: 0,
                refundedUnits: 0,
                revenue: 0,
                daysSinceLastSale: lastSale[product.shopifyID].map {
                    calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: today).day ?? 0
                },
                adSpend: product.adSpend30d,
                inventory: product.inventory,
                tracksInventory: product.tracksInventory,
                abandonedUnits: abandonedUnitsByProduct.map { $0[product.shopifyID] ?? 0 }
            )
            for order in recentOrders {
                for line in order.lines where line.productID == product.shopifyID {
                    performance.units += line.currentQuantity
                    performance.orderedUnits += line.quantity
                    performance.refundedUnits += line.refundedQuantity
                    performance.revenue += line.unitPrice * Decimal(line.currentQuantity)
                }
            }
            return performance
        }
    }
}
