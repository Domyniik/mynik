import SwiftData
import SwiftUI

/// Criar ou editar um prazo do carro (ITV, seguro, imposto...).
struct CarDeadlineFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    private let deadline: CarDeadline?

    @State private var kind: CarDeadlineKind
    @State private var title: String
    @State private var dueDate: Date
    @State private var amount: Decimal
    @State private var renewalMonths: Int
    @State private var notes: String

    init(vehicle: Vehicle, deadline: CarDeadline? = nil) {
        self.vehicle = vehicle
        self.deadline = deadline
        _kind = State(initialValue: deadline?.kind ?? .inspection)
        _title = State(initialValue: deadline?.title ?? "")
        _dueDate = State(initialValue: deadline?.dueDate ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
        _amount = State(initialValue: deadline?.amount ?? 0)
        _renewalMonths = State(initialValue: deadline?.renewalMonths ?? 12)
        _notes = State(initialValue: deadline?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(CarDeadlineKind.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
                    }
                    if kind == .other {
                        TextField("Nome", text: $title)
                    }
                    DatePicker("Vence a", selection: $dueDate, displayedComponents: .date)
                    AmountField(title: "Valor habitual", value: $amount)
                    Picker("Repete", selection: $renewalMonths) {
                        Text("Não se repete").tag(0)
                        Text("Todos os anos").tag(12)
                        Text("De 2 em 2 anos").tag(24)
                        Text("De 6 em 6 meses").tag(6)
                        Text("Todos os meses").tag(1)
                    }
                } footer: {
                    Text(footer)
                }
                Section("Notas") {
                    TextField("Apólice, centro de inspeção…", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(deadline == nil ? "Novo prazo" : "Editar prazo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(kind == .other && title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 440)
        #endif
    }

    private var footer: String {
        switch kind {
        case .inspection: "Em Espanha, a ITV é de 2 em 2 anos entre os 4 e os 10 anos do carro e anual depois. A próxima conta a partir do dia em que passa."
        case .insurance: "Renova na mesma data todos os anos."
        case .tax: "Imposto de circulação (IUC em Portugal, IVTM em Espanha)."
        case .other: "Qualquer prazo que se repete."
        }
    }

    private func save() {
        let target = deadline ?? CarDeadline(kind: kind, dueDate: dueDate)
        if deadline == nil {
            modelContext.insert(target)
            target.vehicle = vehicle
        }
        target.kind = kind
        target.title = kind == .other ? title.trimmingCharacters(in: .whitespaces) : ""
        target.dueDate = dueDate
        target.amount = max(0, amount)
        target.renewalMonths = renewalMonths
        target.notes = notes
        try? modelContext.save()
        dismiss()
    }
}

/// Confirmar que o prazo foi feito: valor pago (vai para as Finanças) e data.
struct CompleteDeadlineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let deadline: CarDeadline

    @State private var amount: Decimal
    @State private var date = Date.now

    init(deadline: CarDeadline) {
        self.deadline = deadline
        _amount = State(initialValue: deadline.amount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Feito a", selection: $date, displayedComponents: .date)
                    AmountField(title: "Valor pago", value: $amount, currencyCode: deadline.currencyCode)
                } footer: {
                    Text(footer)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(deadline.displayTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Feito") {
                        CarExpenseService.complete(deadline, on: date, amount: amount, in: modelContext)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 240)
        #endif
    }

    private var footer: String {
        let finance = amount > 0 ? "O valor entra nas Finanças, na categoria Carro. " : ""
        guard let next = CarExpenseService.nextDueDate(for: deadline, completedOn: date) else {
            return finance + "Este prazo não se repete."
        }
        return finance + "Próximo vencimento: \(next.formatted(.dateTime.day().month(.wide).year().locale(.app)))."
    }
}
