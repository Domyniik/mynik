import Foundation

/// Vai buscar a taxa EUR→BRL do dia à API pública Frankfurter (dados do BCE).
nonisolated enum ExchangeRateService {
    struct Rate: Sendable, Equatable {
        let brlPerEUR: Double
        let date: String
    }

    enum ServiceError: Error {
        case missingRate
    }

    private struct Response: Decodable {
        let date: String
        let rates: [String: Double]
    }

    static let endpoint = URL(string: "https://api.frankfurter.dev/v1/latest?base=EUR&symbols=BRL")!

    static func fetchLatest(session: URLSession = .shared) async throws -> Rate {
        let (data, _) = try await session.data(from: endpoint)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> Rate {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let brl = response.rates["BRL"], brl > 0 else { throw ServiceError.missingRate }
        return Rate(brlPerEUR: brl, date: response.date)
    }
}
