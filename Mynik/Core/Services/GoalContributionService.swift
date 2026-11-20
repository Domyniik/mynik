import Foundation
import SwiftData

/// Regista dinheiro juntado para uma meta.
enum GoalContributionService {
    /// `true` quando a meta aceita contribuições (as ligadas a uma conta seguem o saldo).
    static func acceptsContributions(_ goal: Goal) -> Bool {
        switch goal.source {
        case .manual: true
        case .account: false
        case .category: goal.category != nil
        }
    }

    /// Soma `amount` à meta. Numa meta ligada a uma categoria, cria o movimento
    /// correspondente nas Finanças (na conta indicada).
    @discardableResult
    static func contribute(
        _ amount: Decimal,
        to goal: Goal,
        account: Account?,
        date: Date = .now,
        in context: ModelContext
    ) -> FinanceTransaction? {
        guard amount > 0, acceptsContributions(goal) else { return nil }
        switch goal.source {
        case .manual:
            goal.manualAmount += amount
            return nil
        case .account:
            return nil
        case .category:
            guard let category = goal.category else { return nil }
            let transaction = FinanceTransaction(
                title: "Meta: \(goal.title)",
                amount: amount,
                kind: category.kind,
                date: date,
                currencyCode: goal.currencyCode,
                category: category,
                account: account
            )
            context.insert(transaction)
            return transaction
        }
    }
}
