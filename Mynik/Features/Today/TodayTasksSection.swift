import SwiftData
import SwiftUI

/// Tarefas em curso, atrasadas ou com prazo até hoje, na tela Hoje.
struct TodayTasksSection: View {
    @Query private var openTasks: [ProjectTask]
    @State private var editingTask: ProjectTask?

    init() {
        let done = TaskStatus.done.rawValue
        _openTasks = Query(filter: #Predicate<ProjectTask> { $0.statusRaw != done })
    }

    var body: some View {
        let tasks = TaskBoard.forToday(openTasks)
        Section("Tarefas") {
            if tasks.isEmpty {
                Label("Nada pendente para hoje", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks.prefix(6)) { task in
                    Button { editingTask = task } label: {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                    .taskContextMenu(task) { editingTask = task }
                }
                if tasks.count > 6 {
                    Text("+ \(tasks.count - 6) tarefas em Projetos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $editingTask) { task in
            TaskFormView(task: task)
        }
    }
}
