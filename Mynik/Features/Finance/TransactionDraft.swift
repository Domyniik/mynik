import Foundation

/// Cópia editável de um movimento, usada pelo formulário.
/// Só é aplicada ao modelo quando o utilizador carrega em "Guardar".
struct TransactionDraft {
    var title = ""
    var amount: Decimal = 0
    var kind: TransactionKind = .expense
    var currencyCode = Currency.defaultCode
    var date = Date.now
    var notes = ""
    var category: Category?
    var account: Account?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    init(kind: TransactionKind = .expense) {
        self.kind = kind
    }

    init(_ transaction: FinanceTransaction) {
        title = transaction.title
        amount = transaction.amount
        kind = transaction.kind
        currencyCode = transaction.currencyCode
        date = transaction.date
        notes = transaction.notes
        category = transaction.category
        account = transaction.account
    }

    func apply(to transaction: FinanceTransaction) {
        transaction.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.amount = amount
        transaction.kind = kind
        transaction.currencyCode = currencyCode
        transaction.date = date
        transaction.notes = notes
        transaction.category = category
        transaction.account = account
    }

    func makeTransaction() -> FinanceTransaction {
        let transaction = FinanceTransaction(title: "", amount: 0, kind: kind)
        apply(to: transaction)
        return transaction
    }
}
