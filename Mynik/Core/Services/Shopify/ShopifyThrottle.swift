import Foundation

/// Estado do "balde" de pontos da Admin GraphQL API, tal como vem em
/// `extensions.cost.throttleStatus` em cada resposta.
nonisolated struct ShopifyThrottleStatus: Decodable, Sendable, Equatable {
    var maximumAvailable: Double
    var currentlyAvailable: Double
    var restoreRate: Double
}

/// Calcula quanto esperar antes de um pedido para não exceder o limite.
///
/// A Shopify repõe `restoreRate` pontos por segundo até `maximumAvailable`.
/// Em vez de esperar pelo erro `THROTTLED`, estimamos os pontos disponíveis
/// a partir da última resposta e esperamos só o necessário.
nonisolated struct ShopifyThrottle: Sendable {
    private(set) var status: ShopifyThrottleStatus?
    private(set) var updatedAt: Date?

    mutating func record(_ status: ShopifyThrottleStatus, at date: Date) {
        self.status = status
        updatedAt = date
    }

    /// Pontos que devem estar disponíveis em `date` (ou `nil` sem dados).
    func available(at date: Date) -> Double? {
        guard let status, let updatedAt else { return nil }
        let restored = status.restoreRate * max(0, date.timeIntervalSince(updatedAt))
        return min(status.maximumAvailable, status.currentlyAvailable + restored)
    }

    /// Segundos a esperar antes de gastar `cost` pontos (0 se pode avançar já).
    func delay(beforeSpending cost: Double, at date: Date) -> TimeInterval {
        guard let status, status.restoreRate > 0, let available = available(at: date) else { return 0 }
        let needed = min(cost, status.maximumAvailable)
        guard available < needed else { return 0 }
        return (needed - available) / status.restoreRate
    }
}
