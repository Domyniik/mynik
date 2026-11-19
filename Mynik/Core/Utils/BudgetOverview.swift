import Foundation
import SwiftData

/// Gasto vs orçamento de cada categoria de despesa num mês (valores em EUR).
struct BudgetOverview {
    struct Line: Identifiable {
        let category: Category
        let spent: Decimal

        var id: PersistentIdentifier { category.persistentModelID }
        var budget: Decimal { category.monthlyBudget }
        var hasBudget: Bool { budget > 0 }
        var remaining: Decimal { budget - spent }
        var isOverBudget: Bool { hasBudget && spent > budget }

        /// Fração gasta (0...∞). `0` quando não há orçamento.
        var progress: Double {
            guard hasBudget else { return 0 }
            return NSDecimalNumber(decimal: spent / budget).doubleValue
        }
    }

    let lines: [Line]

    /// Categorias com orçamento definido, as mais "apertadas" primeiro.
    var budgeted: [Line] {
        lines.filter(\.hasBudget).sorted { $0.progress > $1.progress }
    }

    /// Categorias sem orçamento, as que mais gastaram primeiro.
    var unbudgeted: [Line] {
        lines.filter { !$0.hasBudget }.sorted { $0.spent > $1.spent }
    }

    var totalBudget: Decimal { budgeted.reduce(0) { $0 + $1.budget } }
    var totalSpentInBudgeted: Decimal { budgeted.reduce(0) { $0 + $1.spent } }

    init(
        month: Date,
        categories: [Category],
        transactions: [FinanceTransaction],
        converter: CurrencyConverter = CurrencyConverter(),
        calendar: Calendar = .current
    ) {
        var spentByCategory: [PersistentIdentifier: Decimal] = [:]
        for transaction in transactions
        where transaction.kind == .expense
            && calendar.isDate(transaction.date, equalTo: month, toGranularity: .month) {
            guard let category = transaction.category else { continue }
            spentByCategory[category.persistentModelID, default: 0] += converter.amountInDefaultCurrency(transaction)
        }

        lines = categories
            .filter { $0.kind == .expense }
            .map { Line(category: $0, spent: spentByCategory[$0.persistentModelID] ?? 0) }
    }
}
