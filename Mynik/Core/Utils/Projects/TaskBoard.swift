import Foundation

/// Regras de ordenação e seleção de tarefas (Kanban, lista e tela Hoje).
enum TaskBoard {
    /// Ordem dentro de uma coluna: prioridade alta primeiro, depois o prazo
    /// mais próximo (sem prazo no fim) e, por fim, as mais antigas.
    static func sorted(_ tasks: [ProjectTask]) -> [ProjectTask] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority.rawValue > rhs.priority.rawValue }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?) where left != right: return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            default: return lhs.createdAt < rhs.createdAt
            }
        }
    }

    /// Tarefas agrupadas pelas colunas do Kanban, já ordenadas.
    static func columns(_ tasks: [ProjectTask]) -> [TaskStatus: [ProjectTask]] {
        var columns = Dictionary(grouping: tasks, by: \.status).mapValues(sorted)
        for status in TaskStatus.allCases where columns[status] == nil {
            columns[status] = []
        }
        // Feitas: as mais recentes primeiro.
        columns[.done] = columns[.done]?.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return columns
    }

    /// Tarefas para a tela Hoje: em curso, atrasadas ou com prazo até hoje.
    static func forToday(_ tasks: [ProjectTask], now: Date = .now, calendar: Calendar = .current) -> [ProjectTask] {
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let relevant = tasks.filter { task in
            guard !task.isDone else { return false }
            if task.status == .doing { return true }
            guard let due = task.dueDate else { return false }
            return due < endOfToday
        }
        return sorted(relevant)
    }

    /// Prazo de uma tarefa por fazer já passou (antes de hoje).
    static func isOverdue(_ task: ProjectTask, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !task.isDone, let due = task.dueDate else { return false }
        return due < calendar.startOfDay(for: now)
    }
}
