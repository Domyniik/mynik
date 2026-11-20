import Foundation

/// Posto de combustível com os preços do dia.
nonisolated struct FuelStation: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var brand: String
    var address: String
    var town: String
    var latitude: Double
    var longitude: Double
    /// Preço por litro, por `FuelType.rawValue`.
    var prices: [String: Decimal]

    func price(for fuel: FuelType) -> Decimal? { prices[fuel.rawValue] }
}

/// Preços de uma província, como vieram da API (guardados em cache).
nonisolated struct FuelPriceSnapshot: Codable, Sendable {
    var provinceID: String
    /// Hora de atualização indicada pelo Ministerio.
    var publishedAt: Date?
    var fetchedAt: Date
    var stations: [FuelStation]
}

/// Preços de combustível em Espanha (API pública do Ministerio para la Transición
/// Ecológica, sem chave). Os pedidos são por província: o URL não leva
/// localização nem outros dados pessoais.
nonisolated enum FuelPriceService {
    static let baseURL = URL(string: "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/FiltroProvincia/")!

    /// Os preços mudam ao longo do dia; a API atualiza de meia em meia hora.
    static let maximumAge: TimeInterval = 60 * 60

    enum ServiceError: Error {
        case badResponse
    }

    private struct Response: Decodable {
        let fecha: String?
        let lista: [[String: String?]]

        enum CodingKeys: String, CodingKey {
            case fecha = "Fecha"
            case lista = "ListaEESSPrecio"
        }
    }

    static func fetch(provinceID: String, session: URLSession = .shared) async throws -> FuelPriceSnapshot {
        let (data, response) = try await session.data(from: baseURL.appending(path: provinceID))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.badResponse }
        return try decode(data, provinceID: provinceID)
    }

    static func decode(_ data: Data, provinceID: String, now: Date = .now) throws -> FuelPriceSnapshot {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let stations = response.lista.compactMap { row -> FuelStation? in
            func value(_ key: String) -> String { (row[key] ?? nil)?.trimmingCharacters(in: .whitespaces) ?? "" }
            guard let latitude = number(value("Latitud")), let longitude = number(value("Longitud (WGS84)")) else { return nil }
            var prices: [String: Decimal] = [:]
            for fuel in FuelType.allCases {
                if let field = fuel.priceField, let price = decimal(value(field)), price > 0 {
                    prices[fuel.rawValue] = price
                }
            }
            guard !prices.isEmpty else { return nil }
            return FuelStation(
                id: value("IDEESS"),
                brand: value("Rótulo").localizedCapitalized,
                address: value("Dirección").localizedCapitalized,
                town: value("Localidad").localizedCapitalized,
                latitude: latitude,
                longitude: longitude,
                prices: prices
            )
        }
        return FuelPriceSnapshot(
            provinceID: provinceID,
            publishedAt: response.fecha.flatMap(publishedDate),
            fetchedAt: now,
            stations: stations
        )
    }

    /// Os números vêm com vírgula decimal ("1,645").
    static func decimal(_ text: String) -> Decimal? {
        guard !text.isEmpty else { return nil }
        return Decimal(string: text.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private static func publishedDate(_ text: String) -> Date? {
        var strategy = Date.ParseStrategy(
            format: "\(day: .twoDigits)/\(month: .twoDigits)/\(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
            timeZone: TimeZone(identifier: "Europe/Madrid") ?? .current
        )
        strategy.isLenient = true
        return try? Date(text, strategy: strategy)
    }
}

/// Cópia local dos últimos preços de cada província (funciona sem rede).
nonisolated enum FuelPriceCache {
    static var folder: URL {
        URL.cachesDirectory.appending(path: "fuel-prices", directoryHint: .isDirectory)
    }

    static func load(provinceID: String, folder: URL = folder) -> FuelPriceSnapshot? {
        guard let data = try? Data(contentsOf: folder.appending(path: "\(provinceID).json")) else { return nil }
        return try? JSONDecoder().decode(FuelPriceSnapshot.self, from: data)
    }

    static func save(_ snapshot: FuelPriceSnapshot, folder: URL = folder) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: folder.appending(path: "\(snapshot.provinceID).json"), options: .atomic)
    }
}
