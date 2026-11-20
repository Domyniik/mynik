import Foundation
import SwiftData

/// Checkout abandonado (carrinho com contacto do cliente, sem compra).
@Model
final class StoreCheckout {
    var shopifyID: String = ""
    var name: String = ""
    var createdAt: Date = Date.now
    var total: Decimal = 0
    /// Link para o cliente retomar a compra (vazio nos dados de exemplo).
    var recoveryURLString: String = ""
    var lines: [StoreCheckoutLine] = []
    var syncedAt: Date = Date.now

    var recoveryURL: URL? {
        recoveryURLString.isEmpty ? nil : URL(string: recoveryURLString)
    }

    init(shopifyID: String, name: String, createdAt: Date, total: Decimal = 0, lines: [StoreCheckoutLine] = []) {
        self.shopifyID = shopifyID
        self.name = name
        self.createdAt = createdAt
        self.total = total
        self.lines = lines
    }
}

nonisolated struct StoreCheckoutLine: Codable, Hashable, Sendable {
    var productID: String
    var title: String
    var quantity: Int
}
