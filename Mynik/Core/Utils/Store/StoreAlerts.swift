import Foundation

/// Algo na loja que pede atenção.
struct StoreAlert: Identifiable, Equatable {
    enum Kind: String {
        case noSales, productStale, lateOrders, lowStock
    }

    var kind: Kind
    var title: String
    var message: String
    var isCritical = false
    /// Para alertas de produto, o ID do produto.
    var productID: String?

    var id: String { "\(kind.rawValue)-\(productID ?? "")" }

    var symbolName: String {
        switch kind {
        case .noSales: "moon.zzz"
        case .productStale: "hourglass.bottomhalf.filled"
        case .lateOrders: "shippingbox.and.arrow.backward"
        case .lowStock: "exclamationmark.triangle"
        }
    }
}

/// Gera os alertas da loja a partir da cache.
enum StoreAlerts {
    static let defaultNoSaleDays = 3
    /// Um produto ativo sem vendas há este tempo (e com mais de 14 dias) gera alerta.
    static let staleProductDays = 14
    static let lowStockDays = 7

    static func make(
        products: [StoreProduct],
        orders: [StoreOrder],
        noSaleDays: Int = defaultNoSaleDays,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [StoreAlert] {
        var alerts: [StoreAlert] = []

        if let days = daysWithoutSales(orders: orders, now: now, calendar: calendar), days >= noSaleDays {
            alerts.append(StoreAlert(
                kind: .noSales,
                title: "\(days) dias sem venda",
                message: "A última venda foi há \(days) dias. Vale a pena ver os anúncios e o funil.",
                isCritical: days >= noSaleDays * 2
            ))
        }

        let late = StoreOperations.ordersToShip(orders, now: now, calendar: calendar).filter(\.isLate)
        if !late.isEmpty {
            alerts.append(StoreAlert(
                kind: .lateOrders,
                title: late.count == 1 ? "1 pedido atrasado" : "\(late.count) pedidos atrasados",
                message: "À espera de envio há mais de \(StoreOperations.lateAfterDays) dias (o mais antigo: \(late[0].order.name)).",
                isCritical: true
            ))
        }

        let performances = ProductPerformance.build(products: products, orders: orders, now: now, calendar: calendar)
        for product in performances where product.ageDays >= staleProductDays {
            let days = product.daysSinceLastSale ?? product.ageDays
            guard days >= staleProductDays else { continue }
            alerts.append(StoreAlert(
                kind: .productStale,
                title: "\(product.title): \(days) dias sem venda",
                message: product.daysSinceLastSale == nil ? "Ainda não vendeu desde que entrou na loja." : "Considera rever a oferta ou tirar de destaque.",
                productID: product.productID
            ))
        }
        for product in performances {
            guard let days = product.daysOfStock, days < lowStockDays else { continue }
            alerts.append(StoreAlert(
                kind: .lowStock,
                title: "\(product.title): stock para \(days) dias",
                message: "Restam \(product.inventory) unidades ao ritmo de \(product.units) por mês.",
                isCritical: days < 3,
                productID: product.productID
            ))
        }

        return alerts.sorted { $0.isCritical && !$1.isCritical }
    }

    /// Dias desde a última venda (`nil` sem pedidos em cache).
    static func daysWithoutSales(orders: [StoreOrder], now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let last = orders.filter({ !$0.isCancelled }).map(\.createdAt).max() else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day
    }
}
