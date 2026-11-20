import SwiftData
import SwiftUI

/// Botão redondo que marca a tarefa como feita (ou a reabre).
struct TaskStatusButton: View {
    @Environment(\.modelContext) private var modelContext
    let task: ProjectTask

    private var tint: Color {
        switch task.status {
        case .todo: .secondary
        case .doing: .orange
        case .done: .green
        }
    }

    var body: some View {
        Button {
            withAnimation {
                task.status = task.isDone ? .todo : .done
                try? modelContext.save()
            }
        } label: {
            Image(systemName: task.status.symbolName)
                .font(.title3)
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(task.isDone ? "Reabrir tarefa" : "Marcar como feita")
    }
}

/// Prazo, prioridade e projeto de uma tarefa, numa linha curta.
struct TaskMetadata: View {
    let task: ProjectTask
    var showsProject = true

    var body: some View {
        HStack(spacing: 8) {
            if task.priority == .high {
                Label("Alta", systemImage: "exclamationmark.2")
                    .foregroundStyle(.red)
            }
            if let due = task.dueDate {
                Label(due.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
                    .foregroundStyle(TaskBoard.isOverdue(task) ? .red : .secondary)
            }
            if showsProject, let project = task.project {
                Label(project.name, systemImage: project.symbolName)
                    .foregroundStyle(project.color.color)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
    }
}

/// Linha de uma tarefa (lista e tela Hoje).
struct TaskRow: View {
    let task: ProjectTask
    var showsProject = true

    private var hasMetadata: Bool {
        task.priority == .high || task.dueDate != nil || (showsProject && task.project != nil)
    }

    var body: some View {
        HStack(spacing: 10) {
            TaskStatusButton(task: task)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                if hasMetadata {
                    TaskMetadata(task: task, showsProject: showsProject)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }
}

/// Menu de contexto comum às tarefas: editar, mover de coluna e apagar.
struct TaskContextMenu: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    let task: ProjectTask
    let onEdit: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Editar", systemImage: "pencil", action: onEdit)
            Menu("Mover para", systemImage: "arrow.right.circle") {
                ForEach(TaskStatus.allCases) { status in
                    Button(status.title, systemImage: status.symbolName) {
                        withAnimation {
                            task.status = status
                            try? modelContext.save()
                        }
                    }
                    .disabled(status == task.status)
                }
            }
            Divider()
            Button("Apagar", systemImage: "trash", role: .destructive) {
                withAnimation {
                    modelContext.delete(task)
                    try? modelContext.save()
                }
            }
        }
    }
}

extension View {
    func taskContextMenu(_ task: ProjectTask, onEdit: @escaping () -> Void) -> some View {
        modifier(TaskContextMenu(task: task, onEdit: onEdit))
    }
}
