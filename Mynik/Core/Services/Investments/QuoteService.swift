import Foundation

/// Cotação de um ativo.
nonisolated struct Quote: Equatable, Sendable {
    var price: Decimal
    /// Moeda ISO da cotação (ex.: "EUR", "USD").
    var currency: String
    var name: String?
}

/// Cotações gratuitas (Yahoo Finance, sem chave) e câmbio para outras moedas
/// (Frankfurter / BCE). O pedido só leva o ticker: nunca valores nem unidades.
/// A última cotação fica guardada no próprio investimento (funciona sem rede).
nonisolated enum QuoteService {
    enum ServiceError: Error, Equatable {
        case notFound
        case badResponse
    }

    private struct ChartResponse: Decodable {
        struct Chart: Decodable { let result: [Result]? }
        struct Result: Decodable { let meta: Meta }
        struct Meta: Decodable {
            let currency: String?
            let regularMarketPrice: Double?
            let shortName: String?
            let longName: String?
        }
        let chart: Chart
    }

    private struct RateResponse: Decodable {
        let rates: [String: Double]
    }

    static func url(for symbol: String) -> URL? {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/")))
        else { return nil }
        return URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=1d")
    }

    static func fetch(symbol: String, session: URLSession = .shared) async throws -> Quote {
        guard let url = url(for: symbol) else { throw ServiceError.notFound }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Macintosh) Mynik", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { throw ServiceError.notFound }
        guard status == 200 else { throw ServiceError.badResponse }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> Quote {
        let response = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let meta = response.chart.result?.first?.meta,
              let price = meta.regularMarketPrice, price > 0,
              var currency = meta.currency
        else { throw ServiceError.notFound }
        var value = Decimal(string: String(price)) ?? Decimal(price)
        // A bolsa de Londres cota em pence ("GBp").
        if currency == "GBp" || currency == "GBX" {
            value /= 100
            currency = "GBP"
        }
        return Quote(price: value, currency: currency.uppercased(), name: meta.shortName ?? meta.longName)
    }

    /// Quantas unidades de `target` vale 1 `source` (taxa do BCE).
    static func rate(from source: String, to target: String, session: URLSession = .shared) async throws -> Decimal {
        guard source != target else { return 1 }
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=\(source)&symbols=\(target)") else {
            throw ServiceError.badResponse
        }
        let (data, _) = try await session.data(from: url)
        guard let rate = try JSONDecoder().decode(RateResponse.self, from: data).rates[target], rate > 0 else {
            throw ServiceError.badResponse
        }
        return Decimal(string: String(rate)) ?? Decimal(rate)
    }
}
