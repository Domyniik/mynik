import Foundation
import SwiftData

/// Produto da loja, em cache a partir da Shopify.
///
/// Os campos da Shopify são substituídos a cada sincronização; os campos
/// manuais (custo ajustado, gasto em anúncios) mantêm-se.
@Model
final class StoreProduct {
    /// ID global da Shopify (`gid://shopify/Product/…`).
    var shopifyID: String = ""
    var title: String = ""
    var handle: String = ""
    /// `ACTIVE`, `DRAFT` ou `ARCHIVED`.
    var statusRaw: String = "ACTIVE"
    var imageURLString: String = ""
    /// Preço mais baixo das variantes, na moeda da loja.
    var price: Decimal = 0
    /// Custo por unidade (`unitCost` da Shopify, ou o valor manual).
    var unitCost: Decimal = 0
    /// `true` quando o custo foi escrito à mão e não deve ser substituído.
    var unitCostIsManual: Bool = false
    var inventory: Int = 0
    var tracksInventory: Bool = true
    /// Data de criação na Shopify (início do teste do produto).
    var createdAt: Date = Date.now
    /// Gasto em anúncios nos últimos 30 dias (manual), para o ROAS.
    var adSpend30d: Decimal = 0
    var syncedAt: Date = Date.now

    var isActive: Bool { statusRaw == "ACTIVE" }

    var imageURL: URL? { URL(string: imageURLString) }

    /// Margem bruta por unidade (preço − custo), sem anúncios nem taxas.
    var unitMargin: Decimal { price - unitCost }

    init(
        shopifyID: String,
        title: String,
        price: Decimal = 0,
        unitCost: Decimal = 0,
        inventory: Int = 0,
        createdAt: Date = .now
    ) {
        self.shopifyID = shopifyID
        self.title = title
        self.price = price
        self.unitCost = unitCost
        self.inventory = inventory
        self.createdAt = createdAt
    }
}
