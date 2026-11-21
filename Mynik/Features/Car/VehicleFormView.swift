import SwiftData
import SwiftUI

/// Criar ou editar um veículo.
struct VehicleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let vehicle: Vehicle?
    private let onSave: (Vehicle) -> Void

    @State private var name: String
    @State private var plate: String
    @State private var fuelType: FuelType
    @State private var initialOdometer: Int
    @State private var notes: String
    @State private var isConfirmingDelete = false

    init(vehicle: Vehicle? = nil, onSave: @escaping (Vehicle) -> Void = { _ in }) {
        self.vehicle = vehicle
        self.onSave = onSave
        _name = State(initialValue: vehicle?.name ?? "")
        _plate = State(initialValue: vehicle?.plate ?? "")
        _fuelType = State(initialValue: vehicle?.fuelType ?? .gasoline95)
        _initialOdometer = State(initialValue: vehicle?.initialOdometer ?? 0)
        _notes = State(initialValue: vehicle?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (ex.: Golf)", text: $name)
                    TextField("Matrícula", text: $plate)
                        .textInputAutocapitalization(.characters)
                    Picker("Combustível", selection: $fuelType) {
                        ForEach(FuelType.allCases) { Text($0.title).tag($0) }
                    }
                    UnitNumberField(title: "Quilómetros atuais", value: $initialOdometer, unit: "km")
                }
                Section("Notas") {
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if vehicle != nil {
                    Section {
                        Button("Apagar veículo", role: .destructive) { isConfirmingDelete = true }
                    } footer: {
                        Text("Apaga também os abastecimentos, manutenções e prazos. Os movimentos já lançados nas Finanças ficam.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(vehicle == nil ? "Novo veículo" : "Editar veículo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Apagar este veículo?", isPresented: $isConfirmingDelete) {
                Button("Apagar", role: .destructive, action: delete)
            }
        }
    }

    private func save() {
        let target = vehicle ?? Vehicle(name: "")
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.plate = plate.trimmingCharacters(in: .whitespaces).uppercased()
        target.fuelType = fuelType
        target.initialOdometer = max(0, initialOdometer)
        target.notes = notes
        if vehicle == nil { modelContext.insert(target) }
        try? modelContext.save()
        onSave(target)
        dismiss()
    }

    private func delete() {
        guard let vehicle else { return }
        modelContext.delete(vehicle)
        try? modelContext.save()
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    VehicleFormView()
}
