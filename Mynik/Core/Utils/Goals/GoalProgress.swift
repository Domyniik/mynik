import Foundation

/// Progresso de uma meta, calculado a partir das Finanças.
struct GoalProgress {
    /// Valor já juntado, na moeda da meta.
    let current: Decimal
    let target: Decimal
    /// Meses inteiros (arredondados para cima) até ao prazo; `nil` sem prazo ou com o prazo passado.
    let monthsLeft: Int?
    let isPastDeadline: Bool

    var fraction: Double {
        guard target > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: current / target).doubleValue
        return min(1, max(0, value))
    }

    var remaining: Decimal { max(0, target - current) }

    var isReached: Bool { target > 0 && current >= target }

    /// Quanto juntar por mês para chegar ao alvo no prazo.
    var monthlyNeeded: Decimal? {
        guard let monthsLeft, !isReached else { return nil }
        return (remaining / Decimal(monthsLeft)).rounded(scale: 2)
    }

    init(current: Decimal, target: Decimal, monthsLeft: Int?, isPastDeadline: Bool) {
        self.current = current
        self.target = target
        self.monthsLeft = monthsLeft
        self.isPastDeadline = isPastDeadline
    }

    init(goal: Goal, converter: CurrencyConverter, now: Date = .now, calendar: Calendar = .current) {
        let current = Self.savedAmount(for: goal, converter: converter, calendar: calendar)
        var monthsLeft: Int?
        var isPast = false
        if let deadline = goal.deadline {
            let today = calendar.startOfDay(for: now)
            let end = calendar.startOfDay(for: deadline)
            if end < today {
                isPast = true
            } else {
                let parts = calendar.dateComponents([.month, .day], from: today, to: end)
                monthsLeft = max(1, (parts.month ?? 0) + ((parts.day ?? 0) > 0 ? 1 : 0))
            }
        }
        self.init(current: current, target: goal.targetAmount, monthsLeft: monthsLeft, isPastDeadline: isPast)
    }

    /// Valor juntado segundo a origem da meta, convertido para a moeda da meta.
    static func savedAmount(for goal: Goal, converter: CurrencyConverter, calendar: Calendar = .current) -> Decimal {
        switch goal.source {
        case .manual:
            return goal.manualAmount
        case .account:
            guard let account = goal.account else { return 0 }
            return converter.convert(account.balance, from: account.currencyCode, to: goal.currencyCode)
        case .category:
            return contributions(for: goal, calendar: calendar).reduce(0) { total, transaction in
                total + converter.convert(transaction.amount, from: transaction.currencyCode, to: goal.currencyCode)
            }
        }
    }

    /// Movimentos que contam para uma meta ligada a uma categoria (mais recentes primeiro).
    static func contributions(for goal: Goal, calendar: Calendar = .current) -> [FinanceTransaction] {
        guard goal.source == .category, let category = goal.category else { return [] }
        let start = calendar.startOfDay(for: goal.startDate)
        return (category.transactions ?? [])
            .filter { $0.date >= start && $0.kind == category.kind }
            .sorted { $0.date > $1.date }
    }
}

extension Decimal {
    /// Arredonda a `scale` casas decimais (meio para cima).
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
