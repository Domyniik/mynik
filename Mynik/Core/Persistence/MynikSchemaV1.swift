import Foundation
import SwiftData

/// Versão 1 do esquema (v0.1–v0.2), congelada.
///
/// Cópia exata dos modelos tal como foram publicados, para que o SwiftData
/// reconheça bases de dados antigas e as migre para a versão atual.
/// **Não alterar**: mudanças aos modelos entram numa nova versão do esquema.
nonisolated enum MynikSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [FinanceTransaction.self, Category.self, Account.self, Bill.self]
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
}
