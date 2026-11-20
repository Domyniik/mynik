import SwiftData
import SwiftUI

/// Ecrãs secundários de Projetos.
enum ProjectsRoute: Hashable {
    case looseTasks
}

/// Lista de projetos, agrupada por estado.
struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Query(filter: #Predicate<ProjectTask> { $0.project == nil }) private var looseTasks: [ProjectTask]

    @State private var isAddingProject = false
    @State private var editingProject: Project?

    var body: some View {
        List {
            Section {
                NavigationLink(value: ProjectsRoute.looseTasks) {
                    Label("Tarefas avulsas", systemImage: "tray")
                        .badge(looseTasks.count { !$0.isDone })
                }
            }

            if projects.isEmpty {
                ContentUnavailableView {
                    Label("Sem projetos", systemImage: "folder")
                } description: {
                    Text("Organiza o trabalho em projetos com tarefas em Kanban ou em lista.")
                } actions: {
                    Button("Novo projeto") { isAddingProject = true }
                        .buttonStyle(.borderedProminent)
                }
            }

            ForEach(ProjectStatus.allCases) { status in
                let group = projects.filter { $0.status == status }
                if !group.isEmpty {
                    Section(status.title) {
                        ForEach(group) { project in
                            NavigationLink(value: project) {
                                ProjectRow(project: project)
                            }
                            .contextMenu {
                                Button("Editar", systemImage: "pencil") { editingProject = project }
                                Button("Apagar", systemImage: "trash", role: .destructive) { delete(project) }
                            }
                            .swipeActions {
                                Button("Apagar", systemImage: "trash", role: .destructive) { delete(project) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Projetos")
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .navigationDestination(for: ProjectsRoute.self) { route in
            switch route {
            case .looseTasks: LooseTasksView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Novo projeto", systemImage: "plus") { isAddingProject = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingProject) {
            ProjectFormView()
        }
        .sheet(item: $editingProject) { project in
            ProjectFormView(project: project)
        }
    }

    private func delete(_ project: Project) {
        withAnimation {
            modelContext.delete(project)
            try? modelContext.save()
        }
    }
}

/// Linha de um projeto com o progresso das tarefas.
struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: project.symbolName, color: project.color.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !(project.tasks ?? []).isEmpty {
                Gauge(value: project.progress) {
                    Text("Progresso")
                } currentValueLabel: {
                    Text(project.progress, format: .percent.precision(.fractionLength(0)))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(project.color.color)
                .scaleEffect(0.6)
                .frame(width: 34, height: 34)
            }
        }
    }

    private var subtitle: String {
        let open = project.openTaskCount
        var parts = [open == 1 ? "1 tarefa por fazer" : "\(open) tarefas por fazer"]
        if let due = project.dueDate {
            parts.append("prazo \(due.formatted(.dateTime.day().month(.abbreviated)))")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ProjectsView()
    }
}
