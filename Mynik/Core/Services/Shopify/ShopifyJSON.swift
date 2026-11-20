import Foundation

/// Valor monetário da Shopify (`MoneyV2`), que chega como texto: `{"amount": "12.50"}`.
nonisolated struct ShopifyMoney: Decodable, Sendable, Equatable {
    var amount: Decimal

    init(amount: Decimal) {
        self.amount = amount
    }

    private enum CodingKeys: String, CodingKey {
        case amount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try ShopifyJSON.decimal(from: container, forKey: .amount)
    }
}

/// `MoneyBag`: usamos sempre o valor na moeda da loja.
nonisolated struct ShopifyMoneyBag: Decodable, Sendable, Equatable {
    var shopMoney: ShopifyMoney
}

nonisolated enum ShopifyJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = parseDate(text) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Data inválida: \(text)")
            )
        }
        return decoder
    }

    /// Aceita "2026-11-20T10:00:00Z", com ou sem frações de segundo.
    static func parseDate(_ text: String) -> Date? {
        if let date = try? Date(text, strategy: .iso8601) { return date }
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        return try? Date(text, strategy: fractional)
    }

    /// Decimal enviado como texto ("12.50") ou como número.
    static func decimal<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Decimal {
        if let text = try? container.decode(String.self, forKey: key) {
            guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Valor inválido: \(text)")
            }
            return value
        }
        return try container.decode(Decimal.self, forKey: key)
    }
}
