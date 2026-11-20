import Foundation
import SwiftData

/// Projeto com tarefas (vista em Kanban ou em lista).
@Model
final class Project {
    var name: String = ""
    var details: String = ""
    /// Nome de um SF Symbol.
    var symbolName: String = "folder"
    /// Nome de uma cor de `CategoryColor`.
    var colorName: String = CategoryColor.blue.rawValue
    var statusRaw: String = ProjectStatus.active.rawValue
    var dueDate: Date?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask]? = []

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var color: CategoryColor {
        CategoryColor(rawValue: colorName) ?? .blue
    }

    /// Fração de tarefas feitas (0 quando não há tarefas).
    var progress: Double {
        let all = tasks ?? []
        guard !all.isEmpty else { return 0 }
        return Double(all.count { $0.status == .done }) / Double(all.count)
    }

    var openTaskCount: Int {
        (tasks ?? []).count { $0.status != .done }
    }

    init(
        name: String,
        details: String = "",
        symbolName: String = "folder",
        color: CategoryColor = .blue,
        status: ProjectStatus = .active,
        dueDate: Date? = nil
    ) {
        self.name = name
        self.details = details
        self.symbolName = symbolName
        self.colorName = color.rawValue
        self.statusRaw = status.rawValue
        self.dueDate = dueDate
    }
}
