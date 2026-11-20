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
        DashboardCard("Tarefas", systemImage: "checklist") {
            if !tasks.isEmpty {
                Text("\(tasks.count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } content: {
            if tasks.isEmpty {
                EmptyStateView("Dia livre", message: "Nada pendente para hoje.", systemImage: "checkmark.circle")
            } else {
                CardRows(Array(tasks.prefix(6)), dividerInset: 36) { task in
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
