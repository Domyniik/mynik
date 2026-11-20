import Foundation
import SwiftData

/// Pedido da loja, em cache a partir da Shopify.
///
/// Os valores usam os campos `current*` da Shopify, que já descontam
/// devoluções e edições do pedido.
@Model
final class StoreOrder {
    var shopifyID: String = ""
    /// Número visível do pedido, ex.: "#1001".
    var name: String = ""
    var createdAt: Date = Date.now
    var cancelledAt: Date?
    /// Soma dos artigos depois de descontos (com IVA se a loja inclui impostos).
    var subtotal: Decimal = 0
    /// Envio cobrado ao cliente.
    var shipping: Decimal = 0
    var tax: Decimal = 0
    /// Total pago pelo cliente (artigos + envio + impostos).
    var total: Decimal = 0
    var refunded: Decimal = 0
    var currencyCode: String = Currency.defaultCode
    /// `displayFinancialStatus`, ex.: `PAID`, `REFUNDED`.
    var financialStatusRaw: String = ""
    /// `displayFulfillmentStatus`, ex.: `UNFULFILLED`, `FULFILLED`.
    var fulfillmentStatusRaw: String = ""
    var lines: [StoreOrderLine] = []
    var syncedAt: Date = Date.now

    var isCancelled: Bool { cancelledAt != nil }

    /// Receita sem IVA, já sem o que foi devolvido.
    var netRevenue: Decimal { isCancelled ? 0 : total - tax }

    /// Unidades vendidas (sem as devolvidas ou removidas).
    var unitCount: Int { lines.reduce(0) { $0 + $1.currentQuantity } }

    init(
        shopifyID: String,
        name: String,
        createdAt: Date,
        subtotal: Decimal = 0,
        shipping: Decimal = 0,
        tax: Decimal = 0,
        total: Decimal = 0,
        refunded: Decimal = 0,
        financialStatus: String = "PAID",
        fulfillmentStatus: String = "UNFULFILLED",
        lines: [StoreOrderLine] = []
    ) {
        self.shopifyID = shopifyID
        self.name = name
        self.createdAt = createdAt
        self.subtotal = subtotal
        self.shipping = shipping
        self.tax = tax
        self.total = total
        self.refunded = refunded
        self.financialStatusRaw = financialStatus
        self.fulfillmentStatusRaw = fulfillmentStatus
        self.lines = lines
    }
}

/// Linha de um pedido (guardada dentro do pedido).
nonisolated struct StoreOrderLine: Codable, Hashable, Sendable {
    /// ID do produto (vazio se o produto foi apagado).
    var productID: String
    var title: String
    /// Quantidade original.
    var quantity: Int
    /// Quantidade depois de devoluções ou remoções.
    var currentQuantity: Int
    var unitPrice: Decimal

    var refundedQuantity: Int { max(0, quantity - currentQuantity) }
}
