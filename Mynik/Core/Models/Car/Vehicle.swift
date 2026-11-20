import Foundation
import SwiftData

/// Combustível de um veículo. `priceField` é o campo da API de preços
/// do Ministerio (Espanha); `nil` quando não há preços públicos.
nonisolated enum FuelType: String, Codable, CaseIterable, Identifiable, Sendable {
    case gasoline95
    case gasoline98
    case diesel
    case dieselPremium
    case lpg
    case electric

    var id: Self { self }

    var title: String {
        switch self {
        case .gasoline95: "Gasolina 95"
        case .gasoline98: "Gasolina 98"
        case .diesel: "Gasóleo"
        case .dieselPremium: "Gasóleo Premium"
        case .lpg: "GPL (autogás)"
        case .electric: "Elétrico"
        }
    }

    /// Unidade abastecida: litros ou kWh.
    var unit: String { self == .electric ? "kWh" : "L" }

    var priceField: String? {
        switch self {
        case .gasoline95: "Precio Gasolina 95 E5"
        case .gasoline98: "Precio Gasolina 98 E5"
        case .diesel: "Precio Gasoleo A"
        case .dieselPremium: "Precio Gasoleo Premium"
        case .lpg: "Precio Gases licuados del petróleo"
        case .electric: nil
        }
    }
}

/// Carro (ou mota) com abastecimentos, manutenções e prazos (ITV, seguro, imposto).
@Model
final class Vehicle {
    var uid: String = UUID().uuidString
    var name: String = ""
    var plate: String = ""
    var fuelTypeRaw: String = FuelType.gasoline95.rawValue
    /// Quilómetros quando o veículo foi registado na app.
    var initialOdometer: Int = 0
    var notes: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \FuelEntry.vehicle)
    var fuelEntries: [FuelEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecord.vehicle)
    var maintenanceRecords: [MaintenanceRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \CarDeadline.vehicle)
    var deadlines: [CarDeadline]? = []

    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .gasoline95 }
        set { fuelTypeRaw = newValue.rawValue }
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Carro" : trimmed
    }

    /// Maior conta-quilómetros registado (abastecimentos e manutenções incluídos).
    var currentOdometer: Int {
        let fuel = (fuelEntries ?? []).map(\.odometer)
        let maintenance = (maintenanceRecords ?? []).map(\.odometer)
        return ([initialOdometer] + fuel + maintenance).max() ?? initialOdometer
    }

    var sortedFuelEntries: [FuelEntry] {
        (fuelEntries ?? []).sorted { ($0.date, $0.odometer) > ($1.date, $1.odometer) }
    }

    var sortedMaintenance: [MaintenanceRecord] {
        (maintenanceRecords ?? []).sorted { $0.date > $1.date }
    }

    var sortedDeadlines: [CarDeadline] {
        (deadlines ?? []).sorted { $0.dueDate < $1.dueDate }
    }

    init(name: String, plate: String = "", fuelType: FuelType = .gasoline95, initialOdometer: Int = 0) {
        self.name = name
        self.plate = plate
        self.fuelTypeRaw = fuelType.rawValue
        self.initialOdometer = initialOdometer
    }
}
