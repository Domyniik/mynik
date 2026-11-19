import Foundation

/// Receitas, gastos e saldo de um mês, na moeda principal (EUR).
///
/// Movimentos noutras moedas (BRL) são convertidos com o `CurrencyConverter`.
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
        converter: CurrencyConverter = CurrencyConverter(),
        calendar: Calendar = .current
    ) {
        for transaction in transactions
        where calendar.isDate(transaction.date, equalTo: date, toGranularity: .month) {
            let amount = converter.amountInDefaultCurrency(transaction)
            switch transaction.kind {
            case .income: income += amount
            case .expense: expenses += amount
            }
        }
    }
}
