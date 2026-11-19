import Foundation
import SwiftData

/// Regista o pagamento de uma conta ("paguei").
///
/// Cria o gasto correspondente em Finanças e, se a conta for recorrente,
/// avança o vencimento para o período seguinte em vez de a fechar.
enum BillPaymentService {
    @discardableResult
    static func markPaid(
        _ bill: Bill,
        on date: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> FinanceTransaction {
        let transaction = FinanceTransaction(
            title: bill.title,
            amount: bill.amount,
            kind: .expense,
            date: date,
            currencyCode: bill.currencyCode,
            category: bill.category,
            account: bill.account
        )
        context.insert(transaction)

        bill.paidAt = date
        if let nextDueDate = bill.recurrence.nextDate(after: bill.dueDate, calendar: calendar) {
            bill.dueDate = nextDueDate
            bill.isPaid = false
        } else {
            bill.isPaid = true
        }

        return transaction
    }
}
