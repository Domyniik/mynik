import SwiftData
import SwiftUI

/// Forma de ver as tarefas.
enum TaskLayout: String, CaseIterable, Identifiable {
    case board
    case list

    var id: Self { self }

    var title: String {
        switch self {
        case .board: "Quadro"
        case .list: "Lista"
        }
    }

    var symbolName: String {
        switch self {
        case .board: "rectangle.split.3x1"
        case .list: "list.bullet"
        }
    }
}

/// Tarefas em Kanban ou em lista, com cabeçalho opcional (ex.: dados do projeto).
struct TasksScreen<Header: View>: View {
    @Environment(\.modelContext) private var modelContext

    let tasks: [ProjectTask]
    /// Projeto das tarefas novas (`nil` para tarefas avulsas).
    let project: Project?
    @ViewBuilder let header: Header

    @AppStorage(SettingsKey.taskLayout) private var layout = TaskLayout.board
    @State private var newTaskStatus: TaskStatus?
    @State private var editingTask: ProjectTask?

    var body: some View {
        content
            .toolbar {
                ToolbarItem {
                    Picker("Vista", selection: $layout) {
                        ForEach(TaskLayout.allCases) { layout in
                            Label(layout.title, systemImage: layout.symbolName).tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Nova tarefa", systemImage: "plus") { newTaskStatus = .todo }
                        .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(item: $newTaskStatus) { status in
                TaskFormView(project: project, status: status)
            }
            .sheet(item: $editingTask) { task in
                TaskFormView(task: task)
            }
    }

    @ViewBuilder
    private var content: some View {
        let columns = TaskBoard.columns(tasks)
        switch layout {
        case .board:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .padding(.horizontal)
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(TaskStatus.allCases) { status in
                                KanbanColumnView(
                                    status: status,
                                    tasks: columns[status] ?? [],
                                    showsProject: project == nil,
                                    onAdd: { newTaskStatus = $0 },
                                    onEdit: { editingTask = $0 },
                                    onDrop: move
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .scrollIndicators(.hidden)
                }
                .padding(.top)
            }
        case .list:
            List {
                Section { header }
                ForEach(TaskStatus.allCases) { status in
                    if let group = columns[status], !group.isEmpty {
                        Section(status.title) {
                            ForEach(group) { task in
                                Button { editingTask = task } label: {
                                    TaskRow(task: task, showsProject: project == nil)
                                }
                                .buttonStyle(.plain)
                                .taskContextMenu(task) { editingTask = task }
                                .swipeActions {
                                    Button("Apagar", systemImage: "trash", role: .destructive) { delete(task) }
                                }
                            }
                        }
                    }
                }
                if tasks.isEmpty {
                    ContentUnavailableView("Sem tarefas", systemImage: "checklist", description: Text("Adiciona a primeira tarefa com o botão +."))
                }
            }
        }
    }

    /// Larga tarefas (pelo `uid`) numa coluna do Kanban.
    private func move(_ uids: [String], to status: TaskStatus) {
        withAnimation {
            for task in tasks where uids.contains(task.uid) {
                task.status = status
            }
            try? modelContext.save()
        }
    }

    private func delete(_ task: ProjectTask) {
        withAnimation {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }
}
