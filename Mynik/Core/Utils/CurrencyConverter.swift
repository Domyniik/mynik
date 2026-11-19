import Foundation
import SwiftUI

/// Converte valores entre EUR e BRL com uma taxa fixa (BRL por 1 EUR).
///
/// A taxa vem das Definições (manual ou atualizada pelo `ExchangeRateService`).
nonisolated struct CurrencyConverter: Equatable, Sendable {
    static let defaultBRLPerEUR: Double = 6.0

    var brlPerEUR: Decimal

    init(brlPerEUR: Decimal = Decimal(defaultBRLPerEUR)) {
        self.brlPerEUR = brlPerEUR > 0 ? brlPerEUR : Decimal(Self.defaultBRLPerEUR)
    }

    /// A partir do valor guardado nas Definições (`Double`).
    init(storedRate: Double) {
        self.init(brlPerEUR: Decimal(string: String(storedRate)) ?? Decimal(storedRate))
    }

    /// Converte `amount` de `source` para `target` (por omissão, a moeda principal).
    func convert(_ amount: Decimal, from source: String, to target: String = Currency.defaultCode) -> Decimal {
        guard source != target else { return amount }
        switch (source, target) {
        case ("EUR", "BRL"): return amount * brlPerEUR
        case ("BRL", "EUR"): return amount / brlPerEUR
        default: return amount
        }
    }

    /// Valor do movimento na moeda principal.
    func amountInDefaultCurrency(_ transaction: FinanceTransaction) -> Decimal {
        convert(transaction.amount, from: transaction.currencyCode)
    }
}

extension EnvironmentValues {
    /// Conversor com a taxa atual das Definições, injetado em `RootView`.
    @Entry var currencyConverter = CurrencyConverter()
}
