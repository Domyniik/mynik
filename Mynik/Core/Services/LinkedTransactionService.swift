import Foundation
import SwiftData

/// Movimentos das Finanças mantidos por outros módulos (carro, investimentos...).
///
/// Cada movimento é identificado pelo `externalID`, por isso editar o item de
/// origem atualiza o mesmo movimento em vez de criar outro.
enum LinkedTransactionService {
    /// Cria ou atualiza o gasto `externalID`. Com valor zero, apaga-o.
    @discardableResult
    static func upsertExpense(
        externalID: String,
        title: String,
        amount: Decimal,
        currencyCode: String,
        date: Date,
        categoryName: String,
        notes: String = "",
        in context: ModelContext
    ) -> FinanceTransaction? {
        guard amount > 0 else {
            remove(externalID: externalID, in: context)
            return nil
        }
        let transaction = existing(externalID, in: context) ?? {
            let transaction = FinanceTransaction(title: title, amount: amount, kind: .expense)
            transaction.externalID = externalID
            transaction.account = defaultAccount(in: context)
            context.insert(transaction)
            return transaction
        }()
        transaction.title = title
        transaction.amount = amount
        transaction.kind = .expense
        transaction.currencyCode = currencyCode
        transaction.date = date
        transaction.notes = notes
        transaction.category = category(named: categoryName, in: context)
        return transaction
    }

    static func remove(externalID: String, in context: ModelContext) {
        guard !externalID.isEmpty, let transaction = existing(externalID, in: context) else { return }
        context.delete(transaction)
    }

    static func existing(_ externalID: String, in context: ModelContext) -> FinanceTransaction? {
        guard !externalID.isEmpty else { return nil }
        let descriptor = FetchDescriptor<FinanceTransaction>(predicate: #Predicate { $0.externalID == externalID })
        return try? context.fetch(descriptor).first
    }

    private static func category(named name: String, in context: ModelContext) -> Category? {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
        return try? context.fetch(descriptor).first
    }

    static func defaultAccount(in context: ModelContext) -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try? context.fetch(descriptor).first
    }
}
