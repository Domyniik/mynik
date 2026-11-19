import Foundation

/// Receitas, gastos e saldo de um mês.
///
/// Só soma movimentos na moeda principal (EUR); a conversão EUR/BRL
/// chega com o multi-moeda na Fase 2.
struct MonthSummary: Equatable {
    var income: Decimal = 0
    var expenses: Decimal = 0

    var balance: Decimal { income - expenses }

    init(income: Decimal = 0, expenses: Decimal = 0) {
        self.income = income
        self.expenses = expenses
    }

    init(
        month date: Date,
        transactions: [FinanceTransaction],
        currencyCode: String = Currency.defaultCode,
        calendar: Calendar = .current
    ) {
        for transaction in transactions
        where transaction.currencyCode == currencyCode
            && calendar.isDate(transaction.date, equalTo: date, toGranularity: .month) {
            switch transaction.kind {
            case .income: income += transaction.amount
            case .expense: expenses += transaction.amount
            }
        }
    }
}
