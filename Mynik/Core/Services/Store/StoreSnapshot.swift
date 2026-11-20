import Foundation

/// Fotografia da loja vinda de uma fonte (Shopify ou dados de exemplo),
/// pronta a ser escrita na cache SwiftData por `StoreCacheWriter`.
nonisolated struct StoreSnapshot: Sendable {
    var shopName: String
    var products: [ProductRecord]
    var orders: [OrderRecord]
    /// Tráfego diário. Vazio quando a loja não dá acesso aos relatórios.
    var traffic: [TrafficRecord]
    /// Motivo para não haver tráfego, para mostrar ao utilizador.
    var trafficUnavailableReason: String?

    struct ProductRecord: Sendable, Equatable {
        var id: String
        var title: String
        var handle: String
        var status: String
        var imageURL: String
        var price: Decimal
        /// `nil` quando a Shopify não tem custo definido.
        var unitCost: Decimal?
        var inventory: Int
        var tracksInventory: Bool
        var createdAt: Date
        /// Gasto em anúncios inicial (só nos dados de exemplo; na loja real é manual).
        var adSpend30d: Decimal? = nil
    }

    struct OrderRecord: Sendable, Equatable {
        var id: String
        var name: String
        var createdAt: Date
        var cancelledAt: Date?
        var subtotal: Decimal
        var shipping: Decimal
        var tax: Decimal
        var total: Decimal
        var refunded: Decimal
        var currencyCode: String
        var financialStatus: String
        var fulfillmentStatus: String
        var lines: [StoreOrderLine]
    }

    struct TrafficRecord: Sendable, Equatable {
        /// Início do dia, no fuso horário local.
        var day: Date
        var sessions: Int
        var cartSessions: Int
        var checkoutSessions: Int
        var completedSessions: Int
    }
}

/// De onde vêm os dados da loja.
nonisolated protocol StoreDataSource: Sendable {
    /// Lê produtos, pedidos desde `since` e tráfego diário.
    func fetchSnapshot(since: Date) async throws -> StoreSnapshot
}
