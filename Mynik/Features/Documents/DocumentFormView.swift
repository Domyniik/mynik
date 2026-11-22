import SwiftData
import SwiftUI

/// Criar ou editar um documento.
struct DocumentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let document: PersonalDocument?

    @State private var kind: DocumentKind
    @State private var title: String
    @State private var number: String
    @State private var issuer: String
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date
    @State private var remindDaysBefore: Int
    @State private var notes: String

    init(document: PersonalDocument? = nil) {
        self.document = document
        _kind = State(initialValue: document?.kind ?? .idCard)
        _title = State(initialValue: document?.title ?? "")
        _number = State(initialValue: document?.number ?? "")
        _issuer = State(initialValue: document?.issuer ?? "")
        _hasExpiry = State(initialValue: document.map { $0.expiryDate != nil } ?? true)
        _expiryDate = State(initialValue: document?.expiryDate ?? Calendar.current.date(byAdding: .year, value: 5, to: .now) ?? .now)
        _remindDaysBefore = State(initialValue: document?.remindDaysBefore ?? 60)
        _notes = State(initialValue: document?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(DocumentKind.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
                    }
                    TextField("Nome (opcional)", text: $title)
                    TextField("Número", text: $number)
                        .autocorrectionDisabled()
                    TextField("Emitido por (opcional)", text: $issuer)
                }
                Section {
                    Toggle("Tem validade", isOn: $hasExpiry.animation())
                    if hasExpiry {
                        DatePicker("Expira a", selection: $expiryDate, displayedComponents: .date)
                        Picker("Avisar", selection: $remindDaysBefore) {
                            Text("1 mês antes").tag(30)
                            Text("2 meses antes").tag(60)
                            Text("3 meses antes").tag(90)
                            Text("6 meses antes").tag(180)
                        }
                    }
                } footer: {
                    if hasExpiry {
                        Text("Renovar o passaporte ou a residência pode demorar: recebes um aviso antes, outro 7 dias antes e no próprio dia.")
                    }
                }
                Section("Notas") {
                    TextField("Notas", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(document == nil ? "Novo documento" : "Editar documento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                }
            }
        }
    }

    private func save() {
        let target = document ?? PersonalDocument(kind: kind)
        target.kind = kind
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.number = number.trimmingCharacters(in: .whitespaces)
        target.issuer = issuer.trimmingCharacters(in: .whitespaces)
        target.expiryDate = hasExpiry ? expiryDate : nil
        target.remindDaysBefore = remindDaysBefore
        target.notes = notes
        if document == nil { modelContext.insert(target) }
        try? modelContext.save()
        dismiss()
    }
}
