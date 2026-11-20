import Foundation

/// Cópia editável de uma tarefa, usada pelo formulário.
struct TaskDraft {
    var title = ""
    var notes = ""
    var status: TaskStatus = .todo
    var priority: TaskPriority = .normal
    var hasDueDate = false
    var dueDate = Date.now
    var project: Project?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(project: Project? = nil, status: TaskStatus = .todo) {
        self.project = project
        self.status = status
    }

    init(_ task: ProjectTask) {
        title = task.title
        notes = task.notes
        status = task.status
        priority = task.priority
        hasDueDate = task.dueDate != nil
        dueDate = task.dueDate ?? .now
        project = task.project
    }

    func apply(to task: ProjectTask) {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = notes
        task.status = status
        task.priority = priority
        task.dueDate = hasDueDate ? dueDate : nil
        task.project = project
    }

    func makeTask() -> ProjectTask {
        let task = ProjectTask(title: "")
        apply(to: task)
        return task
    }
}
