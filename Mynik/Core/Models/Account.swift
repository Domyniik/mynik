import Foundation
import SwiftData

/// Conta onde o dinheiro está (banco, poupança, cartão, dinheiro vivo).
@Model
final class Account {
    /// Identificador estável entre dispositivos (cópias de segurança e importação).
    var uid: String = UUID().uuidString
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

    /// Metas cujo progresso segue o saldo desta conta.
    @Relationship(deleteRule: .nullify, inverse: \Goal.account)
    var goals: [Goal]? = []

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
