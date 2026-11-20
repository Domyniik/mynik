import Foundation
import SwiftData

/// Conta a pagar (renda, luz, seguro...). Uma conta recorrente nunca fica
/// "paga": ao pagar, o vencimento avança (ver `BillPaymentService`).
@Model
final class Bill {
    /// Identificador estável entre dispositivos (cópias de segurança e importação).
    var uid: String = UUID().uuidString
    var title: String = ""
    var amount: Decimal = 0
    var currencyCode: String = Currency.defaultCode
    var dueDate: Date = Date.now
    var isPaid: Bool = false
    var paidAt: Date?
    var recurrenceRaw: String = BillRecurrence.none.rawValue
    var notes: String = ""
    /// Assinatura (Spotify, ginásio...): entra no total mensal/anual de assinaturas.
    var isSubscription: Bool = false
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
        isSubscription: Bool = false,
        currencyCode: String = Currency.defaultCode,
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.recurrenceRaw = recurrence.rawValue
        self.isSubscription = isSubscription
        self.currencyCode = currencyCode
        self.category = category
        self.account = account
    }
}
