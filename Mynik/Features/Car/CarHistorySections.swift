import SwiftData
import SwiftUI

/// Últimos abastecimentos do veículo.
struct FuelHistorySection: View {
    let vehicle: Vehicle
    @Binding var sheet: CarSheet?

    @Environment(\.modelContext) private var modelContext
    @State private var showsAll = false

    var body: some View {
        let entries = vehicle.sortedFuelEntries
        Section("Abastecimentos") {
            if entries.isEmpty {
                Button("Registar abastecimento", systemImage: "fuelpump") { sheet = .fuel(vehicle, nil) }
            }
            ForEach(showsAll ? entries : Array(entries.prefix(5))) { entry in
                Button { sheet = .fuel(vehicle, entry) } label: {
                    FuelEntryRow(entry: entry, unit: vehicle.fuelType.unit)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Apagar", systemImage: "trash", role: .destructive) { delete(entry) }
                }
                .contextMenu {
                    Button("Apagar", systemImage: "trash", role: .destructive) { delete(entry) }
                }
            }
            if entries.count > 5 {
                Button(showsAll ? "Mostrar menos" : "Ver todos (\(entries.count))") {
                    withAnimation { showsAll.toggle() }
                }
            }
        }
    }

    private func delete(_ entry: FuelEntry) {
        withAnimation {
            CarExpenseService.delete(entry, in: modelContext)
            try? modelContext.save()
        }
    }
}

struct FuelEntryRow: View {
    let entry: FuelEntry
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: "fuelpump.fill", color: entry.isFullTank ? .indigo : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.station.isEmpty ? "Abastecimento" : entry.station)
                    .lineLimit(1)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Currency.format(entry.totalCost, code: entry.currencyCode))
                .monospacedDigit()
        }
        .contentShape(.rect)
    }

    private var details: String {
        var parts = [
            entry.date.formatted(.dateTime.day().month(.abbreviated).locale(.app)),
            "\(entry.quantity.formatted(.number.precision(.fractionLength(0...2)).locale(.app))) \(unit)",
            "\(entry.odometer.formatted(.number.locale(.app))) km",
        ]
        if let price = entry.unitPrice {
            parts.append("\(price.formatted(.number.precision(.fractionLength(3)).locale(.app))) €/\(unit)")
        }
        if !entry.isFullTank { parts.append("parcial") }
        return parts.joined(separator: " · ")
    }
}

/// Histórico de manutenções do veículo.
struct MaintenanceHistorySection: View {
    let vehicle: Vehicle
    @Binding var sheet: CarSheet?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Section("Manutenções") {
            if vehicle.sortedMaintenance.isEmpty {
                Button("Registar manutenção", systemImage: "wrench.and.screwdriver") { sheet = .maintenance(vehicle, nil) }
            }
            ForEach(vehicle.sortedMaintenance) { record in
                Button { sheet = .maintenance(vehicle, record) } label: {
                    MaintenanceRow(record: record)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Apagar", systemImage: "trash", role: .destructive) { delete(record) }
                }
                .contextMenu {
                    Button("Apagar", systemImage: "trash", role: .destructive) { delete(record) }
                }
            }
        }
    }

    private func delete(_ record: MaintenanceRecord) {
        withAnimation {
            CarExpenseService.delete(record, in: modelContext)
            try? modelContext.save()
        }
    }
}

struct MaintenanceRow: View {
    let record: MaintenanceRecord

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: record.kind.symbolName, color: .teal)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayTitle).lineLimit(1)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if record.cost > 0 {
                Text(Currency.format(record.cost, code: record.currencyCode)).monospacedDigit()
            }
        }
        .contentShape(.rect)
    }

    private var details: String {
        var parts = [record.date.formatted(.dateTime.day().month(.abbreviated).year().locale(.app))]
        if record.odometer > 0 { parts.append("\(record.odometer.formatted(.number.locale(.app))) km") }
        if !record.workshop.isEmpty { parts.append(record.workshop) }
        if let next = record.nextDueDate {
            parts.append("próxima \(next.formatted(.dateTime.month(.abbreviated).year().locale(.app)))")
        } else if record.nextDueOdometer > 0 {
            parts.append("próxima aos \(record.nextDueOdometer.formatted(.number.locale(.app))) km")
        }
        return parts.joined(separator: " · ")
    }
}
