import Foundation
import SwiftData

/// Versão 2 do esquema (v0.3), congelada.
///
/// Acrescentou a cache da loja Shopify. Cópia exata dos modelos tal como foram
/// publicados na v0.3.0, para que o SwiftData reconheça essas bases de dados e
/// as migre para a versão atual.
/// **Não alterar**: mudanças aos modelos entram numa nova versão do esquema.
nonisolated enum MynikSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            FinanceTransaction.self, Category.self, Account.self, Bill.self,
            StoreProduct.self, StoreOrder.self, DailyStat.self, StoreCheckout.self,
        ]
    }

    @Model
    final class FinanceTransaction {
        var title: String = ""
        var amount: Decimal = 0
        var kindRaw: String = "expense"
        var currencyCode: String = "EUR"
        var date: Date = Date.now
        var notes: String = ""
        var createdAt: Date = Date.now
        var externalID: String = ""

        var category: Category?
        var account: Account?

        init() {}
    }

    @Model
    final class Category {
        var name: String = ""
        var symbolName: String = "tag"
        var colorName: String = "gray"
        var kindRaw: String = "expense"
        var sortOrder: Int = 0
        var monthlyBudget: Decimal = 0

        @Relationship(deleteRule: .nullify, inverse: \FinanceTransaction.category)
        var transactions: [FinanceTransaction]? = []

        @Relationship(deleteRule: .nullify, inverse: \Bill.category)
        var bills: [Bill]? = []

        init() {}
    }

    @Model
    final class Account {
        var name: String = ""
        var typeRaw: String = "checking"
        var currencyCode: String = "EUR"
        var initialBalance: Decimal = 0
        var isArchived: Bool = false
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .nullify, inverse: \FinanceTransaction.account)
        var transactions: [FinanceTransaction]? = []

        @Relationship(deleteRule: .nullify, inverse: \Bill.account)
        var bills: [Bill]? = []

        init() {}
    }

    @Model
    final class Bill {
        var title: String = ""
        var amount: Decimal = 0
        var currencyCode: String = "EUR"
        var dueDate: Date = Date.now
        var isPaid: Bool = false
        var paidAt: Date?
        var recurrenceRaw: String = "none"
        var notes: String = ""
        var isSubscription: Bool = false
        var createdAt: Date = Date.now

        var category: Category?
        var account: Account?

        init() {}
    }

    @Model
    final class StoreProduct {
        var shopifyID: String = ""
        var title: String = ""
        var handle: String = ""
        var statusRaw: String = "ACTIVE"
        var imageURLString: String = ""
        var price: Decimal = 0
        var unitCost: Decimal = 0
        var unitCostIsManual: Bool = false
        var inventory: Int = 0
        var tracksInventory: Bool = true
        var createdAt: Date = Date.now
        var adSpend30d: Decimal = 0
        var decisionRaw: String = ""
        var decidedAt: Date?
        var decisionNote: String = ""
        var syncedAt: Date = Date.now

        init() {}
    }

    @Model
    final class StoreOrder {
        var shopifyID: String = ""
        var name: String = ""
        var createdAt: Date = Date.now
        var cancelledAt: Date?
        var subtotal: Decimal = 0
        var shipping: Decimal = 0
        var tax: Decimal = 0
        var total: Decimal = 0
        var refunded: Decimal = 0
        var currencyCode: String = "EUR"
        var financialStatusRaw: String = ""
        var fulfillmentStatusRaw: String = ""
        var lines: [StoreOrderLine] = []
        var syncedAt: Date = Date.now

        init() {}
    }

    @Model
    final class DailyStat {
        var date: Date = Date.now
        var sales: Decimal = 0
        var netRevenue: Decimal = 0
        var orders: Int = 0
        var units: Int = 0
        var refunds: Decimal = 0
        var sessions: Int = 0
        var cartSessions: Int = 0
        var checkoutSessions: Int = 0
        var completedSessions: Int = 0
        var hasTraffic: Bool = false

        init() {}
    }

    @Model
    final class StoreCheckout {
        var shopifyID: String = ""
        var name: String = ""
        var createdAt: Date = Date.now
        var total: Decimal = 0
        var recoveryURLString: String = ""
        var lines: [StoreCheckoutLine] = []
        var syncedAt: Date = Date.now

        init() {}
    }
}
