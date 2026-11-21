import SwiftData
import SwiftUI

/// Formulário para criar ou editar uma tarefa.
struct TaskFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Project.name) private var projects: [Project]

    private let task: ProjectTask?
    @State private var draft: TaskDraft
    @State private var isShowingSaveError = false

    init(task: ProjectTask? = nil, project: Project? = nil, status: TaskStatus = .todo) {
        self.task = task
        _draft = State(initialValue: task.map(TaskDraft.init) ?? TaskDraft(project: project, status: status))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tarefa", text: $draft.title)
                    TextField("Notas", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Picker("Estado", selection: $draft.status) {
                        ForEach(TaskStatus.allCases) { status in
                            Label(status.title, systemImage: status.symbolName).tag(status)
                        }
                    }
                    Picker("Prioridade", selection: $draft.priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    Toggle("Tem prazo", isOn: $draft.hasDueDate.animation())
                    if draft.hasDueDate {
                        DatePicker("Prazo", selection: $draft.dueDate, displayedComponents: .date)
                    }
                }

                Section {
                    Picker("Projeto", selection: $draft.project) {
                        Text("Sem projeto").tag(Project?.none)
                        ForEach(projects) { project in
                            Label(project.name, systemImage: project.symbolName).tag(Optional(project))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(task == nil ? "Nova tarefa" : "Editar tarefa")
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
        if let task {
            draft.apply(to: task)
        } else {
            modelContext.insert(draft.makeTask())
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
    TaskFormView()
}
