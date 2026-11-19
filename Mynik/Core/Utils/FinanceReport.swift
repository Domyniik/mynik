import Foundation

/// Dados agregados para os gráficos de Finanças (valores em EUR).
enum FinanceReport {
    struct CategorySlice: Identifiable, Equatable {
        let name: String
        let symbolName: String
        let color: CategoryColor
        let amount: Decimal

        var id: String { name }
    }

    struct MonthTotals: Identifiable, Equatable {
        let month: Date
        let income: Decimal
        let expenses: Decimal

        var id: Date { month }
        var balance: Decimal { income - expenses }
    }

    /// Gastos do mês por categoria, do maior para o menor.
    static func expensesByCategory(
        month: Date,
        transactions: [FinanceTransaction],
        converter: CurrencyConverter = CurrencyConverter(),
        calendar: Calendar = .current
    ) -> [CategorySlice] {
        var totals: [String: (category: Category?, amount: Decimal)] = [:]

        for transaction in transactions
        where transaction.kind == .expense
            && calendar.isDate(transaction.date, equalTo: month, toGranularity: .month) {
            let key = transaction.category?.name ?? uncategorizedName
            let amount = converter.amountInDefaultCurrency(transaction)
            totals[key, default: (transaction.category, 0)].amount += amount
        }

        return totals
            .map { name, entry in
                CategorySlice(
                    name: name,
                    symbolName: entry.category?.symbolName ?? "questionmark",
                    color: entry.category?.color ?? .gray,
                    amount: entry.amount
                )
            }
            .sorted { $0.amount == $1.amount ? $0.name < $1.name : $0.amount > $1.amount }
    }

    /// Receitas e gastos dos últimos `count` meses, do mais antigo para `month`.
    static func monthlyTotals(
        endingAt month: Date,
        count: Int = 6,
        transactions: [FinanceTransaction],
        converter: CurrencyConverter = CurrencyConverter(),
        calendar: Calendar = .current
    ) -> [MonthTotals] {
        guard let lastMonth = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        let months = (0..<count).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: lastMonth)
        }

        return months.map { start in
            let summary = MonthSummary(month: start, transactions: transactions, converter: converter, calendar: calendar)
            return MonthTotals(month: start, income: summary.income, expenses: summary.expenses)
        }
    }

    static let uncategorizedName = "Sem categoria"
}
