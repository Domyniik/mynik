import Foundation

/// Consumo a partir dos abastecimentos, pelo método do depósito cheio:
/// entre dois atestos, o consumo é o que se meteu depois do primeiro
/// (incluindo abastecimentos parciais) a dividir pelos quilómetros feitos.
nonisolated struct FuelEconomy: Sendable {
    struct Fill: Sendable {
        var date: Date
        var odometer: Int
        var quantity: Double
        var cost: Decimal
        var isFullTank: Bool
    }

    /// Troço entre dois atestos.
    struct Segment: Sendable, Equatable {
        var endDate: Date
        var distance: Int
        var quantity: Double
        var cost: Decimal

        /// Litros (ou kWh) aos 100 km.
        var per100km: Double { distance > 0 ? quantity / Double(distance) * 100 : 0 }
    }

    let segments: [Segment]

    init(fills: [Fill]) {
        let sorted = fills.sorted { ($0.odometer, $0.date) < ($1.odometer, $1.date) }
        var segments: [Segment] = []
        var start: Fill?
        var quantity = 0.0
        var cost: Decimal = 0
        for fill in sorted {
            guard let first = start else {
                if fill.isFullTank { start = fill }
                continue
            }
            quantity += fill.quantity
            cost += fill.cost
            guard fill.isFullTank else { continue }
            let distance = fill.odometer - first.odometer
            if distance > 0 {
                segments.append(Segment(endDate: fill.date, distance: distance, quantity: quantity, cost: cost))
            }
            start = fill
            quantity = 0
            cost = 0
        }
        self.segments = segments
    }

    init(entries: [FuelEntry]) {
        self.init(fills: entries.map {
            Fill(date: $0.date, odometer: $0.odometer, quantity: $0.quantity, cost: $0.totalCost, isFullTank: $0.isFullTank)
        })
    }

    var totalDistance: Int { segments.reduce(0) { $0 + $1.distance } }

    /// Consumo médio (L/100 km), ou `nil` sem dois atestos.
    var averagePer100km: Double? {
        guard totalDistance > 0 else { return nil }
        return segments.reduce(0) { $0 + $1.quantity } / Double(totalDistance) * 100
    }

    var lastPer100km: Double? { segments.last?.per100km }

    /// Custo do combustível por quilómetro.
    var costPerKm: Decimal? {
        guard totalDistance > 0 else { return nil }
        return segments.reduce(Decimal(0)) { $0 + $1.cost } / Decimal(totalDistance)
    }
}
