import Foundation

/// Património em EUR: dinheiro nas contas, investido e valor dos investimentos.
struct WealthSummary: Equatable {
    var cash: Decimal = 0
    var invested: Decimal = 0
    var investmentsValue: Decimal = 0

    var netWorth: Decimal { cash + investmentsValue }
    var gain: Decimal { investmentsValue - invested }

    var gainFraction: Double? {
        invested > 0 ? NSDecimalNumber(decimal: gain / invested).doubleValue : nil
    }

    init(cash: Decimal = 0, invested: Decimal = 0, investmentsValue: Decimal = 0) {
        self.cash = cash
        self.invested = invested
        self.investmentsValue = investmentsValue
    }

    init(accounts: [Account], investments: [Investment], converter: CurrencyConverter) {
        cash = accounts
            .filter { !$0.isArchived }
            .reduce(0) { $0 + converter.convert($1.balance, from: $1.currencyCode) }
        for investment in investments where !investment.isArchived {
            invested += converter.convert(investment.investedAmount, from: investment.currencyCode)
            investmentsValue += converter.convert(investment.currentValue, from: investment.currencyCode)
        }
    }
}

/// Poupança de um mês: receitas − gastos, contando os aportes a investimentos
/// como dinheiro poupado (não gasto).
nonisolated struct SavingsProgress: Equatable, Sendable {
    var income: Decimal = 0
    var expenses: Decimal = 0
    var contributions: Decimal = 0
    var target: Decimal = 0

    var saved: Decimal { income - expenses + contributions }

    /// Fração das receitas que foi poupada (`nil` sem receitas).
    var rate: Double? {
        income > 0 ? NSDecimalNumber(decimal: saved / income).doubleValue : nil
    }

    /// Progresso para a meta mensal, de 0 a 1 (`nil` sem meta).
    var targetFraction: Double? {
        guard target > 0 else { return nil }
        return min(1, max(0, NSDecimalNumber(decimal: saved / target).doubleValue))
    }

    var remainingToTarget: Decimal { max(0, target - saved) }
}

extension SavingsProgress {
    init(
        month: Date,
        transactions: [FinanceTransaction],
        target: Decimal,
        converter: CurrencyConverter,
        calendar: Calendar = .current
    ) {
        let summary = MonthSummary(month: month, transactions: transactions, converter: converter, calendar: calendar)
        let contributions = transactions
            .filter {
                $0.kind == .expense
                    && $0.category?.name == InvestmentService.categoryName
                    && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            .reduce(Decimal(0)) { $0 + converter.amountInDefaultCurrency($1) }
        self.init(income: summary.income, expenses: summary.expenses, contributions: contributions, target: target)
    }
}
