import Foundation

/// O dia a dia da loja: pedidos por enviar e carrinhos abandonados.
enum StoreOperations {
    /// Pedidos à espera mais do que isto estão atrasados.
    static let lateAfterDays = 3

    /// Estados da Shopify em que o pedido ainda tem de ser enviado.
    static let pendingFulfillmentStatuses: Set<String> = [
        "UNFULFILLED", "PARTIALLY_FULFILLED", "IN_PROGRESS", "OPEN", "PENDING_FULFILLMENT", "ON_HOLD", "REQUEST_DECLINED",
    ]

    struct PendingOrder: Identifiable {
        let order: StoreOrder
        let daysWaiting: Int

        var id: String { order.shopifyID }
        var isLate: Bool { daysWaiting > StoreOperations.lateAfterDays }
    }

    /// Pedidos pagos por enviar, do mais antigo para o mais recente.
    static func ordersToShip(_ orders: [StoreOrder], now: Date = .now, calendar: Calendar = .current) -> [PendingOrder] {
        let today = calendar.startOfDay(for: now)
        return orders
            .filter { order in
                !order.isCancelled
                    && order.unitCount > 0
                    && pendingFulfillmentStatuses.contains(order.fulfillmentStatusRaw)
                    && order.financialStatusRaw != "REFUNDED"
            }
            .sorted { $0.createdAt < $1.createdAt }
            .map { order in
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: order.createdAt), to: today).day ?? 0
                return PendingOrder(order: order, daysWaiting: max(0, days))
            }
    }

    /// Checkouts abandonados nos últimos `days` dias (o mais recente primeiro).
    static func recentCheckouts(_ checkouts: [StoreCheckout], days: Int = 30, now: Date = .now, calendar: Calendar = .current) -> [StoreCheckout] {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
        return checkouts.filter { $0.createdAt >= start }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Unidades deixadas em checkouts por produto, para o funil do ranking.
    /// `nil` quando não há checkouts em cache (sem dados, não "zero abandonos").
    static func abandonedUnitsByProduct(_ checkouts: [StoreCheckout], now: Date = .now, calendar: Calendar = .current) -> [String: Int]? {
        guard !checkouts.isEmpty else { return nil }
        var units: [String: Int] = [:]
        for checkout in recentCheckouts(checkouts, days: ProductPerformance.windowDays, now: now, calendar: calendar) {
            for line in checkout.lines where !line.productID.isEmpty {
                units[line.productID, default: 0] += line.quantity
            }
        }
        return units
    }
}
