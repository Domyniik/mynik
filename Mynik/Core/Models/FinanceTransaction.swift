import Foundation
import SwiftData

/// Um gasto ou uma receita.
///
/// Chama-se `FinanceTransaction` (e não `Transaction`) para não colidir com
/// `SwiftUI.Transaction`. Compatível com CloudKit: todas as propriedades têm
/// valor por omissão e as relações são opcionais.
@Model
final class FinanceTransaction {
    var title: String = ""
    /// Valor sempre positivo; o sinal vem de `kind`.
    var amount: Decimal = 0
    /// Guardado como texto para poder ser usado em `#Predicate`.
    var kindRaw: String = TransactionKind.expense.rawValue
    var currencyCode: String = Currency.defaultCode
    var date: Date = Date.now
    var notes: String = ""
    var createdAt: Date = Date.now

    var category: Category?
    var account: Account?

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    /// Valor com sinal: negativo para gastos, positivo para receitas.
    var signedAmount: Decimal {
        kind == .expense ? -amount : amount
    }

    init(
        title: String,
        amount: Decimal,
        kind: TransactionKind,
        date: Date = .now,
        currencyCode: String = Currency.defaultCode,
        notes: String = "",
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.title = title
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.date = date
        self.currencyCode = currencyCode
        self.notes = notes
        self.category = category
        self.account = account
    }
}
