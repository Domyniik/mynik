import Foundation

/// Moedas suportadas e formatação de valores.
nonisolated enum Currency {
    static let defaultCode = "EUR"
    static let supportedCodes = ["EUR", "BRL"]
    static let locale = Locale(identifier: "pt_PT")

    static func format(_ amount: Decimal, code: String = defaultCode) -> String {
        amount.formatted(.currency(code: code).locale(locale))
    }
}
