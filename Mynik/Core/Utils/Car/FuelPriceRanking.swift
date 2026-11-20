import Foundation

/// Escolhe os postos mais baratos (perto do utilizador, quando há localização).
nonisolated enum FuelPriceRanking {
    struct Entry: Identifiable, Sendable {
        let station: FuelStation
        let price: Decimal
        /// Distância em km, quando há localização.
        let distance: Double?

        var id: String { station.id }
    }

    struct Coordinate: Sendable, Equatable {
        var latitude: Double
        var longitude: Double
    }

    /// Postos com preço para `fuel`, do mais barato para o mais caro.
    /// Com `origin`, só os que ficam até `radius` km (se nenhum ficar, usa todos).
    static func cheapest(
        _ stations: [FuelStation],
        fuel: FuelType,
        near origin: Coordinate? = nil,
        radius: Double = 10
    ) -> [Entry] {
        let entries = stations.compactMap { station -> Entry? in
            guard let price = station.price(for: fuel) else { return nil }
            let distance = origin.map {
                distanceKm(from: $0, to: Coordinate(latitude: station.latitude, longitude: station.longitude))
            }
            return Entry(station: station, price: price, distance: distance)
        }
        let nearby = entries.filter { ($0.distance ?? 0) <= radius }
        return (nearby.isEmpty ? entries : nearby).sorted {
            ($0.price, $0.distance ?? 0) < ($1.price, $1.distance ?? 0)
        }
    }

    /// Média de preços de `fuel` na província.
    static func average(_ stations: [FuelStation], fuel: FuelType) -> Decimal? {
        let prices = stations.compactMap { $0.price(for: fuel) }
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / Decimal(prices.count)
    }

    /// Distância em linha reta (fórmula de haversine).
    static func distanceKm(from a: Coordinate, to b: Coordinate) -> Double {
        let radians = Double.pi / 180
        let dLat = (b.latitude - a.latitude) * radians
        let dLon = (b.longitude - a.longitude) * radians
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(a.latitude * radians) * cos(b.latitude * radians) * sin(dLon / 2) * sin(dLon / 2)
        return 6_371 * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}
