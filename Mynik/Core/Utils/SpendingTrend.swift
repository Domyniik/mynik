import Foundation

/// Séries diárias dos gastos, para os mini gráficos dos cartões.
enum SpendingTrend {
    /// Gastos acumulados em cada dia do mês de `now`, do dia 1 até hoje (moeda principal).
    static func cumulativeExpenses(
        month now: Date,
        transactions: [FinanceTransaction],
        converter: CurrencyConverter = CurrencyConverter(),
        calendar: Calendar = .current
    ) -> [Double] {
        let today = calendar.component(.day, from: now)
        var perDay = Array(repeating: 0.0, count: today)
        for transaction in transactions
        where transaction.kind == .expense
            && calendar.isDate(transaction.date, equalTo: now, toGranularity: .month) {
            let day = calendar.component(.day, from: transaction.date)
            guard day <= today else { continue }
            perDay[day - 1] += NSDecimalNumber(decimal: converter.amountInDefaultCurrency(transaction)).doubleValue
        }
        var total = 0.0
        return perDay.map { total += $0; return total }
    }
}
