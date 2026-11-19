import Foundation
import SwiftData

/// Conta onde o dinheiro está (banco, poupança, cartão, dinheiro vivo).
@Model
final class Account {
    var name: String = ""
    var typeRaw: String = AccountType.checking.rawValue
    var currencyCode: String = Currency.defaultCode
    var initialBalance: Decimal = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \FinanceTransaction.account)
    var transactions: [FinanceTransaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Bill.account)
    var bills: [Bill]? = []

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .checking }
        set { typeRaw = newValue.rawValue }
    }

    /// Saldo inicial mais todos os movimentos da conta.
    var balance: Decimal {
        (transactions ?? []).reduce(initialBalance) { $0 + $1.signedAmount }
    }

    init(
        name: String,
        type: AccountType = .checking,
        currencyCode: String = Currency.defaultCode,
        initialBalance: Decimal = 0
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
    }
}
