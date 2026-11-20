import SwiftData
import SwiftUI

/// Um projeto: descrição, progresso e tarefas (Kanban ou lista).
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project

    @State private var isEditing = false
    @State private var openedNote: Note?

    var body: some View {
        TasksScreen(tasks: project.tasks ?? [], project: project) {
            ProjectHeader(project: project, onOpenNote: { openedNote = $0 }, onNewNote: newNote)
        }
        .navigationTitle(project.name)
        .navigationDestination(item: $openedNote) { note in
            NoteEditorView(note: note)
        }
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button("Editar projeto", systemImage: "pencil") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ProjectFormView(project: project)
        }
    }

    /// Cria uma nota já ligada ao projeto e abre-a.
    private func newNote() {
        let note = NoteEditing.makeNote(title: project.name, in: modelContext)
        NoteLinks.toggle(project, in: note)
        try? modelContext.save()
        openedNote = note
    }
}

/// Resumo do projeto no topo do detalhe.
struct ProjectHeader: View {
    let project: Project
    var onOpenNote: (Note) -> Void = { _ in }
    var onNewNote: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !project.details.isEmpty {
                Text(project.details)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label(project.status.title, systemImage: project.status.symbolName)
                if let due = project.dueDate {
                    Label("Prazo \(due.formatted(.dateTime.day().month(.abbreviated).year()))", systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            let total = project.tasks?.count ?? 0
            if total > 0 {
                ProgressView(value: project.progress) {
                    Text("\(total - project.openTaskCount) de \(total) tarefas feitas")
                        .font(.caption)
                }
                .tint(project.color.color)
            }

            HStack(spacing: 8) {
                ForEach(project.linkedNotes ?? []) { note in
                    Button { onOpenNote(note) } label: {
                        Label { Text(note.displayTitle).lineLimit(1) } icon: { Text(note.icon) }
                    }
                }
                Button("Nota", systemImage: "plus", action: onNewNote)
                    .help("Nova nota ligada ao projeto")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tarefas sem projeto.
struct LooseTasksView: View {
    @Query(filter: #Predicate<ProjectTask> { $0.project == nil }) private var tasks: [ProjectTask]

    var body: some View {
        TasksScreen(tasks: tasks, project: nil) {
            Text("Tarefas que não pertencem a nenhum projeto.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Tarefas avulsas")
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var projects: [Project]
    NavigationStack {
        if let project = projects.first {
            ProjectDetailView(project: project)
        }
    }
}
