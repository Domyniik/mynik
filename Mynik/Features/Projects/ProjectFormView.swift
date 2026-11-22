import SwiftData
import SwiftUI

/// Formulário para criar ou editar um projeto.
struct ProjectFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let project: Project?
    @State private var draft: ProjectDraft
    @State private var isShowingSaveError = false

    init(project: Project? = nil) {
        self.project = project
        _draft = State(initialValue: project.map(ProjectDraft.init) ?? ProjectDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome", text: $draft.name)
                    TextField("Descrição", text: $draft.details, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Picker("Estado", selection: $draft.status) {
                        ForEach(ProjectStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    Toggle("Tem prazo", isOn: $draft.hasDueDate.animation())
                    if draft.hasDueDate {
                        DatePicker("Prazo", selection: $draft.dueDate, displayedComponents: .date)
                    }
                }

                Section("Cor") {
                    ColorChoicePicker(selection: $draft.color)
                }

                Section("Ícone") {
                    SymbolChoicePicker(symbols: ProjectDraft.symbols, tint: draft.color.color, selection: $draft.symbolName)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(project == nil ? "Novo projeto" : "Editar projeto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .alert("Não foi possível guardar", isPresented: $isShowingSaveError) { }
        }
    }

    private func save() {
        if let project {
            draft.apply(to: project)
        } else {
            modelContext.insert(draft.makeProject())
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            isShowingSaveError = true
        }
    }
}

#Preview(traits: .sampleData) {
    ProjectFormView()
}
