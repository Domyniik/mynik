import SwiftData
import SwiftUI

/// Registar ou editar uma manutenção, com a próxima opcional.
struct MaintenanceFormView: View {
    /// Quando é a próxima manutenção.
    enum NextDue: String, CaseIterable, Identifiable {
        case none, date, odometer
        var id: Self { self }
        var title: String {
            switch self {
            case .none: "Sem próxima"
            case .date: "Numa data"
            case .odometer: "Aos km"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    private let record: MaintenanceRecord?

    @State private var kind: MaintenanceKind
    @State private var title: String
    @State private var date: Date
    @State private var odometer: Int
    @State private var cost: Decimal
    @State private var workshop: String
    @State private var notes: String
    @State private var nextDue: NextDue
    @State private var nextDate: Date
    @State private var nextOdometer: Int
    @State private var postsToFinance: Bool

    init(vehicle: Vehicle, record: MaintenanceRecord? = nil) {
        self.vehicle = vehicle
        self.record = record
        _kind = State(initialValue: record?.kind ?? .service)
        _title = State(initialValue: record?.title ?? "")
        _date = State(initialValue: record?.date ?? .now)
        _odometer = State(initialValue: record?.odometer ?? vehicle.currentOdometer)
        _cost = State(initialValue: record?.cost ?? 0)
        _workshop = State(initialValue: record?.workshop ?? "")
        _notes = State(initialValue: record?.notes ?? "")
        let next: NextDue = if record?.nextDueDate != nil { .date } else if (record?.nextDueOdometer ?? 0) > 0 { .odometer } else { .none }
        _nextDue = State(initialValue: next)
        _nextDate = State(initialValue: record?.nextDueDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now)
        _nextOdometer = State(initialValue: (record?.nextDueOdometer ?? 0) > 0 ? record?.nextDueOdometer ?? 0 : vehicle.currentOdometer + 15_000)
        _postsToFinance = State(initialValue: record.map { !$0.transactionID.isEmpty } ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(MaintenanceKind.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
                    }
                    TextField("Descrição (opcional)", text: $title)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    UnitNumberField(title: "Conta-quilómetros", value: $odometer, unit: "km")
                    AmountField(title: "Custo", value: $cost)
                    TextField("Oficina (opcional)", text: $workshop)
                }
                Section {
                    Picker("Próxima", selection: $nextDue.animation()) {
                        ForEach(NextDue.allCases) { Text($0.title).tag($0) }
                    }
                    switch nextDue {
                    case .none: EmptyView()
                    case .date: DatePicker("Data", selection: $nextDate, displayedComponents: .date)
                    case .odometer: UnitNumberField(title: "Aos", value: $nextOdometer, unit: "km")
                    }
                } footer: {
                    Text("A próxima manutenção aparece na tela Hoje quando estiver perto.")
                }
                Section {
                    TextField("Notas", text: $notes, axis: .vertical).lineLimit(2...5)
                    Toggle("Lançar nas Finanças (Carro)", isOn: $postsToFinance)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(record == nil ? "Manutenção" : "Editar manutenção")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 560)
        #endif
    }

    private func save() {
        let target = record ?? MaintenanceRecord(kind: kind)
        if record == nil {
            modelContext.insert(target)
            target.vehicle = vehicle
        }
        target.kind = kind
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.date = date
        target.odometer = max(0, odometer)
        target.cost = max(0, cost)
        target.workshop = workshop.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.nextDueDate = nextDue == .date ? nextDate : nil
        target.nextDueOdometer = nextDue == .odometer ? nextOdometer : 0
        CarExpenseService.sync(target, post: postsToFinance, in: modelContext)
        try? modelContext.save()
        dismiss()
    }
}
