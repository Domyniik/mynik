import Foundation

/// Cópia editável de uma conta a pagar, usada pelo formulário.
struct BillDraft {
    var title = ""
    var amount: Decimal = 0
    var currencyCode = Currency.defaultCode
    var dueDate = Date.now
    var recurrence: BillRecurrence = .monthly
    var isSubscription = false
    var notes = ""
    var category: Category?
    var account: Account?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    init(isSubscription: Bool = false) {
        self.isSubscription = isSubscription
    }

    init(_ bill: Bill) {
        title = bill.title
        amount = bill.amount
        currencyCode = bill.currencyCode
        dueDate = bill.dueDate
        recurrence = bill.recurrence
        isSubscription = bill.isSubscription
        notes = bill.notes
        category = bill.category
        account = bill.account
    }

    func apply(to bill: Bill) {
        bill.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        bill.amount = amount
        bill.currencyCode = currencyCode
        bill.dueDate = dueDate
        bill.recurrence = recurrence
        bill.isSubscription = isSubscription
        bill.notes = notes
        bill.category = category
        bill.account = account
    }

    func makeBill() -> Bill {
        let bill = Bill(title: "", amount: 0, dueDate: dueDate)
        apply(to: bill)
        return bill
    }
}
