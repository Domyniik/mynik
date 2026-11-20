import Foundation

/// Cópia editável de um projeto, usada pelo formulário.
struct ProjectDraft {
    static let symbols = [
        "folder", "hammer", "laptopcomputer", "paintbrush", "book", "house", "car",
        "airplane", "dumbbell", "graduationcap", "briefcase", "storefront", "camera",
        "music.note", "heart", "leaf",
    ]

    var name = ""
    var details = ""
    var symbolName = "folder"
    var color: CategoryColor = .blue
    var status: ProjectStatus = .active
    var hasDueDate = false
    var dueDate = Date.now

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {}

    init(_ project: Project) {
        name = project.name
        details = project.details
        symbolName = project.symbolName
        color = project.color
        status = project.status
        hasDueDate = project.dueDate != nil
        dueDate = project.dueDate ?? .now
    }

    func apply(to project: Project) {
        project.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        project.details = details
        project.symbolName = symbolName
        project.colorName = color.rawValue
        project.status = status
        project.dueDate = hasDueDate ? dueDate : nil
    }

    func makeProject() -> Project {
        let project = Project(name: "")
        apply(to: project)
        return project
    }
}
