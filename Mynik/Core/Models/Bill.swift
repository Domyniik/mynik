import Foundation
import SwiftData

/// Conta a pagar (renda, luz, seguro...). A recorrência completa e o botão
/// "paguei" chegam na Fase 2; o modelo já guarda o necessário.
@Model
final class Bill {
    var title: String = ""
    var amount: Decimal = 0
    var currencyCode: String = Currency.defaultCode
    var dueDate: Date = Date.now
    var isPaid: Bool = false
    var paidAt: Date?
    var recurrenceRaw: String = BillRecurrence.none.rawValue
    var notes: String = ""
    var createdAt: Date = Date.now

    var category: Category?
    var account: Account?

    var recurrence: BillRecurrence {
        get { BillRecurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    init(
        title: String,
        amount: Decimal,
        dueDate: Date,
        recurrence: BillRecurrence = .none,
        currencyCode: String = Currency.defaultCode,
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.recurrenceRaw = recurrence.rawValue
        self.currencyCode = currencyCode
        self.category = category
        self.account = account
    }
}
