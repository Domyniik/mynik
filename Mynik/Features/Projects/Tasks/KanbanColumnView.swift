import SwiftUI

/// Cartão de uma tarefa no Kanban.
struct TaskCard: View {
    let task: ProjectTask
    var showsProject = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.callout)
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            TaskMetadata(task: task, showsProject: showsProject)
        }
        .padding(10)
        .background(.background, in: .rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .contentShape(.rect(cornerRadius: 10))
    }
}

/// Coluna do Kanban: aceita tarefas arrastadas de outras colunas.
struct KanbanColumnView: View {
    let status: TaskStatus
    let tasks: [ProjectTask]
    var showsProject = false
    let onAdd: (TaskStatus) -> Void
    let onEdit: (ProjectTask) -> Void
    let onDrop: ([String], TaskStatus) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(status.title, systemImage: status.symbolName)
                    .font(.headline)
                Spacer()
                Text(tasks.count, format: .number)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ForEach(tasks) { task in
                TaskCard(task: task, showsProject: showsProject)
                    .onTapGesture { onEdit(task) }
                    .draggable(task.uid) {
                        TaskCard(task: task, showsProject: showsProject)
                            .frame(width: 240)
                    }
                    .taskContextMenu(task) { onEdit(task) }
            }

            if status != .done {
                Button("Adicionar tarefa", systemImage: "plus") { onAdd(status) }
                    .buttonStyle(.borderless)
                    .font(.callout)
            }
        }
        .padding(10)
        .frame(width: 280, alignment: .topLeading)
        .frame(minHeight: 160, alignment: .top)
        .background(isTargeted ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.fill.quaternary), in: .rect(cornerRadius: 14))
        .dropDestination(for: String.self) { uids, _ in
            onDrop(uids, status)
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.default, value: isTargeted)
    }
}
