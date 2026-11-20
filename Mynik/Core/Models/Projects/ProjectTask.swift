import Foundation
import SwiftData

/// Tarefa, dentro de um projeto ou avulsa (sem projeto).
///
/// Chama-se `ProjectTask` (e não `Task`) para não colidir com a concorrência do Swift.
@Model
final class ProjectTask {
    /// Identificador estável, usado no arrastar e largar do Kanban.
    var uid: String = UUID().uuidString
    var title: String = ""
    var notes: String = ""
    var statusRaw: String = TaskStatus.todo.rawValue
    var priorityRaw: Int = TaskPriority.normal.rawValue
    var dueDate: Date?
    var completedAt: Date?
    var createdAt: Date = Date.now

    var project: Project?

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set {
            guard newValue != status else { return }
            statusRaw = newValue.rawValue
            completedAt = newValue == .done ? .now : nil
        }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var isDone: Bool { status == .done }

    init(
        title: String,
        notes: String = "",
        status: TaskStatus = .todo,
        priority: TaskPriority = .normal,
        dueDate: Date? = nil,
        project: Project? = nil
    ) {
        self.title = title
        self.notes = notes
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.completedAt = status == .done ? .now : nil
        self.project = project
    }
}
