import Foundation

/// Lê valores em texto como os que a automação "Transação" dos Atalhos envia:
/// "12,50 €", "€12.50", "1.234,56 €", "R$ 10,00", "12.5".
nonisolated enum AmountTextParser {
    struct Result: Equatable {
        var amount: Decimal
        var currencyCode: String
    }

    static func parse(_ text: String) -> Result? {
        let upper = text.uppercased()
        let currency = upper.contains("R$") || upper.contains("BRL") ? "BRL" : Currency.defaultCode

        // Fica só com dígitos e separadores.
        let kept = String(text.filter { $0.isNumber || $0 == "," || $0 == "." })
        guard kept.contains(where: \.isNumber) else { return nil }

        // O último separador seguido de 1 ou 2 dígitos é o decimal; os outros são de milhares.
        var integerPart = kept
        var fraction = ""
        if let index = kept.lastIndex(where: { $0 == "," || $0 == "." }) {
            let after = kept[kept.index(after: index)...]
            if (1...2).contains(after.count), after.allSatisfy(\.isNumber) {
                integerPart = String(kept[..<index])
                fraction = String(after)
            }
        }
        let digits = integerPart.filter(\.isNumber)
        guard let amount = Decimal(string: "\(digits.isEmpty ? "0" : digits).\(fraction.isEmpty ? "0" : fraction)", locale: Locale(identifier: "en_US_POSIX")),
              amount > 0 else { return nil }
        return Result(amount: amount, currencyCode: currency)
    }
}
