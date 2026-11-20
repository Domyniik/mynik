import SwiftData
import SwiftUI

/// Folhas abertas a partir do ecrã Carro.
enum CarSheet: Identifiable {
    case vehicle(Vehicle?)
    case fuel(Vehicle, FuelEntry?)
    case maintenance(Vehicle, MaintenanceRecord?)
    case deadline(Vehicle, CarDeadline?)
    case complete(CarDeadline)

    var id: String {
        switch self {
        case .vehicle(let vehicle): "vehicle-\(vehicle?.uid ?? "new")"
        case .fuel(_, let entry): "fuel-\(entry?.uid ?? "new")"
        case .maintenance(_, let record): "maintenance-\(record?.uid ?? "new")"
        case .deadline(_, let deadline): "deadline-\(deadline?.uid ?? "new")"
        case .complete(let deadline): "complete-\(deadline.uid)"
        }
    }
}

/// Carro: resumo e consumo, prazos (ITV, seguro, imposto), preços de combustível,
/// abastecimentos e manutenções.
struct CarView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage(SettingsKey.selectedVehicleUID) private var selectedUID = ""

    @State private var sheet: CarSheet?

    private var vehicle: Vehicle? {
        vehicles.first { $0.uid == selectedUID } ?? vehicles.first
    }

    var body: some View {
        List {
            if let vehicle {
                if vehicles.count > 1 {
                    Picker("Veículo", selection: $selectedUID) {
                        ForEach(vehicles) { Text($0.displayName).tag($0.uid) }
                    }
                }
                CarSummarySection(vehicle: vehicle)
                CarDeadlinesSection(vehicle: vehicle, sheet: $sheet)
                FuelPricesSection(fuelType: vehicle.fuelType)
                FuelHistorySection(vehicle: vehicle, sheet: $sheet)
                MaintenanceHistorySection(vehicle: vehicle, sheet: $sheet)
            } else {
                ContentUnavailableView {
                    Label("Sem carro", systemImage: "car")
                } description: {
                    Text("Regista o carro para seguir o consumo, as manutenções e os prazos da ITV, do seguro e do imposto.")
                } actions: {
                    Button("Adicionar carro") { sheet = .vehicle(nil) }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .navigationTitle(vehicle?.displayName ?? "Carro")
        .navigationDestination(for: FuelType.self) { fuel in
            FuelPricesView(fuelType: fuel)
        }
        .toolbar { toolbar }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .vehicle(let vehicle): VehicleFormView(vehicle: vehicle) { selectedUID = $0.uid }
            case .fuel(let vehicle, let entry): FuelEntryFormView(vehicle: vehicle, entry: entry)
            case .maintenance(let vehicle, let record): MaintenanceFormView(vehicle: vehicle, record: record)
            case .deadline(let vehicle, let deadline): CarDeadlineFormView(vehicle: vehicle, deadline: deadline)
            case .complete(let deadline): CompleteDeadlineSheet(deadline: deadline)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let vehicle {
            ToolbarItem(placement: .primaryAction) {
                Menu("Adicionar", systemImage: "plus") {
                    Button("Abastecimento", systemImage: "fuelpump") { sheet = .fuel(vehicle, nil) }
                    Button("Manutenção", systemImage: "wrench.and.screwdriver") { sheet = .maintenance(vehicle, nil) }
                    Button("Prazo (ITV, seguro…)", systemImage: "calendar.badge.clock") { sheet = .deadline(vehicle, nil) }
                    Divider()
                    Button("Outro veículo", systemImage: "car.2") { sheet = .vehicle(nil) }
                } primaryAction: {
                    sheet = .fuel(vehicle, nil)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Editar veículo", systemImage: "pencil") { sheet = .vehicle(vehicle) }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        CarView()
    }
}
