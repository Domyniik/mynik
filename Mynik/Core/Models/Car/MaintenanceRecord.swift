import Foundation
import SwiftData

/// Tipo de manutenção.
nonisolated enum MaintenanceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case service
    case oil
    case tyres
    case brakes
    case battery
    case repair
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .service: "Revisão"
        case .oil: "Mudança de óleo"
        case .tyres: "Pneus"
        case .brakes: "Travões"
        case .battery: "Bateria"
        case .repair: "Reparação"
        case .other: "Outra"
        }
    }

    var symbolName: String {
        switch self {
        case .service: "wrench.and.screwdriver"
        case .oil: "drop"
        case .tyres: "circle.circle"
        case .brakes: "exclamationmark.octagon"
        case .battery: "minus.plus.batteryblock"
        case .repair: "hammer"
        case .other: "car"
        }
    }
}

/// Manutenção feita no veículo, com a próxima opcional (por data ou quilómetros).
@Model
final class MaintenanceRecord {
    var uid: String = UUID().uuidString
    var kindRaw: String = MaintenanceKind.service.rawValue
    var title: String = ""
    var date: Date = Date.now
    var odometer: Int = 0
    var cost: Decimal = 0
    var currencyCode: String = Currency.defaultCode
    var workshop: String = ""
    var notes: String = ""
    var nextDueDate: Date?
    /// Quilómetros da próxima manutenção (`0` = sem limite).
    var nextDueOdometer: Int = 0
    /// `externalID` do movimento nas Finanças; vazio se não foi lançado.
    var transactionID: String = ""
    var createdAt: Date = Date.now

    var vehicle: Vehicle?

    var kind: MaintenanceKind {
        get { MaintenanceKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.title : trimmed
    }

    init(
        kind: MaintenanceKind,
        title: String = "",
        date: Date = .now,
        odometer: Int = 0,
        cost: Decimal = 0,
        vehicle: Vehicle? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.date = date
        self.odometer = odometer
        self.cost = cost
        self.vehicle = vehicle
    }
}
