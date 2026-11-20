import SwiftData
import SwiftUI

/// Registar ou editar um abastecimento.
struct FuelEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    private let entry: FuelEntry?

    @State private var date: Date
    @State private var odometer: Int
    @State private var quantity: Double
    @State private var totalCost: Decimal
    @State private var isFullTank: Bool
    @State private var station: String
    @State private var postsToFinance: Bool

    init(vehicle: Vehicle, entry: FuelEntry? = nil) {
        self.vehicle = vehicle
        self.entry = entry
        _date = State(initialValue: entry?.date ?? .now)
        _odometer = State(initialValue: entry?.odometer ?? vehicle.currentOdometer)
        _quantity = State(initialValue: entry?.quantity ?? 0)
        _totalCost = State(initialValue: entry?.totalCost ?? 0)
        _isFullTank = State(initialValue: entry?.isFullTank ?? true)
        _station = State(initialValue: entry?.station ?? "")
        _postsToFinance = State(initialValue: entry.map { !$0.transactionID.isEmpty } ?? true)
    }

    private var unit: String { vehicle.fuelType.unit }

    private var isValid: Bool { odometer > 0 && quantity > 0 && totalCost > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Data", selection: $date)
                    UnitNumberField(title: "Conta-quilómetros", value: $odometer, unit: "km")
                    UnitDecimalField(title: vehicle.fuelType == .electric ? "Energia" : "Litros", value: $quantity, unit: unit)
                    AmountField(title: "Total pago", value: $totalCost)
                    if quantity > 0, totalCost > 0 {
                        LabeledContent("Preço") {
                            Text("\((totalCost / Decimal(quantity)).formatted(.number.precision(.fractionLength(3)).locale(.app))) €/\(unit)")
                                .monospacedDigit()
                        }
                    }
                    Toggle("Depósito atestado", isOn: $isFullTank)
                } footer: {
                    Text("Para calcular o consumo, ateste o depósito: o consumo é medido entre dois atestos.")
                }
                Section {
                    TextField("Posto (opcional)", text: $station)
                    Toggle("Lançar nas Finanças (Carro)", isOn: $postsToFinance)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(entry == nil ? "Abastecimento" : "Editar abastecimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).disabled(!isValid)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    private func save() {
        let target = entry ?? FuelEntry(odometer: 0, quantity: 0, totalCost: 0)
        if entry == nil {
            modelContext.insert(target)
            target.vehicle = vehicle
        }
        target.date = date
        target.odometer = odometer
        target.quantity = quantity
        target.totalCost = totalCost
        target.isFullTank = isFullTank
        target.station = station.trimmingCharacters(in: .whitespaces)
        CarExpenseService.sync(target, post: postsToFinance, in: modelContext)
        try? modelContext.save()
        dismiss()
    }
}
