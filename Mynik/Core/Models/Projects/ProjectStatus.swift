import Foundation

/// Estado de um projeto.
nonisolated enum ProjectStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case paused
    case done

    var id: Self { self }

    var title: String {
        switch self {
        case .active: "Em curso"
        case .paused: "Em pausa"
        case .done: "Concluídos"
        }
    }

    var symbolName: String {
        switch self {
        case .active: "play.circle"
        case .paused: "pause.circle"
        case .done: "checkmark.circle"
        }
    }
}

/// Coluna do Kanban onde está uma tarefa.
nonisolated enum TaskStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case todo
    case doing
    case done

    var id: Self { self }

    var title: String {
        switch self {
        case .todo: "Por fazer"
        case .doing: "Em curso"
        case .done: "Feito"
        }
    }

    var symbolName: String {
        switch self {
        case .todo: "circle"
        case .doing: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        }
    }

    /// Estado seguinte ao tocar no ícone da tarefa.
    var next: TaskStatus {
        switch self {
        case .todo: .doing
        case .doing: .done
        case .done: .todo
        }
    }
}

/// Prioridade de uma tarefa.
nonisolated enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Sendable {
    case low = 0
    case normal = 1
    case high = 2

    var id: Self { self }

    var title: String {
        switch self {
        case .low: "Baixa"
        case .normal: "Normal"
        case .high: "Alta"
        }
    }
}
