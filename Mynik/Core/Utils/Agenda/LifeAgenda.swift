import Foundation
import SwiftData

/// Junta os prazos dos módulos de vida (carro, documentos, carreira).
enum LifeAgenda {
    /// Todos os itens com data, de todos os módulos.
    static func allItems(in context: ModelContext, now: Date = .now) -> [AgendaItem] {
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        return carItems(vehicles, now: now)
    }

    /// Prazos do carro (ITV, seguro, imposto) e próximas manutenções.
    static func carItems(_ vehicles: [Vehicle], now: Date = .now) -> [AgendaItem] {
        vehicles.flatMap { vehicle -> [AgendaItem] in
            let deadlines = (vehicle.deadlines ?? []).map { deadline in
                AgendaItem(
                    id: "car-deadline-\(deadline.uid)",
                    title: deadline.displayTitle,
                    detail: vehicle.displayName,
                    date: deadline.dueDate,
                    symbolName: deadline.kind.symbolName,
                    source: .car,
                    remindDaysBefore: [30, 7, 0]
                )
            }
            return deadlines + maintenanceItems(vehicle, now: now)
        }
    }

    /// A manutenção mais recente de cada tipo, se tiver a próxima marcada.
    private static func maintenanceItems(_ vehicle: Vehicle, now: Date) -> [AgendaItem] {
        let latestByKind = Dictionary(grouping: vehicle.maintenanceRecords ?? [], by: \.kind)
            .compactMap { $0.value.max { $0.date < $1.date } }
        return latestByKind.compactMap { record in
            if let next = record.nextDueDate {
                return AgendaItem(
                    id: "car-maintenance-\(record.uid)",
                    title: record.displayTitle,
                    detail: vehicle.displayName,
                    date: next,
                    symbolName: record.kind.symbolName,
                    source: .car,
                    dueWord: "Próxima",
                    horizonDays: 14,
                    remindDaysBefore: [7, 0]
                )
            }
            let remaining = record.nextDueOdometer - vehicle.currentOdometer
            guard record.nextDueOdometer > 0, remaining <= 1_000 else { return nil }
            let km = abs(remaining).formatted(.number.locale(.app))
            return AgendaItem(
                id: "car-maintenance-\(record.uid)",
                title: record.displayTitle,
                detail: remaining > 0 ? "\(vehicle.displayName) · faltam \(km) km" : "\(vehicle.displayName) · passou \(km) km",
                date: now,
                symbolName: record.kind.symbolName,
                source: .car,
                dueWord: "Próxima",
                remindDaysBefore: []
            )
        }
    }
}
