import Foundation

/// Custo das assinaturas em EUR, normalizado por mês e por ano.
struct SubscriptionSummary {
    let monthlyTotal: Decimal

    var yearlyTotal: Decimal { monthlyTotal * 12 }

    init(bills: [Bill], converter: CurrencyConverter = CurrencyConverter()) {
        monthlyTotal = bills
            .filter(\.isSubscription)
            .reduce(0) { $0 + Self.monthlyCost(of: $1, converter: converter) }
    }

    /// Custo mensal equivalente de uma conta recorrente, em EUR.
    static func monthlyCost(of bill: Bill, converter: CurrencyConverter = CurrencyConverter()) -> Decimal {
        let amount = converter.convert(bill.amount, from: bill.currencyCode)
        return bill.recurrence.monthlyAmount(for: amount) ?? 0
    }
}
