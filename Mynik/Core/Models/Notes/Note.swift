import Foundation
import SwiftData

/// Página de notas (estilo Notion): tem blocos e pode ter subpáginas.
@Model
final class Note {
    /// Identificador estável (foco no editor e ligações).
    var uid: String = UUID().uuidString
    var title: String = ""
    /// Emoji mostrado antes do título.
    var icon: String = "📄"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var sortOrder: Int = 0

    var parent: Note?

    @Relationship(deleteRule: .cascade, inverse: \Note.parent)
    var children: [Note]? = []

    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.note)
    var blocks: [NoteBlock]? = []

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sem título" : trimmed
    }

    var sortedBlocks: [NoteBlock] {
        (blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedChildren: [Note] {
        (children ?? []).sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    /// Subpáginas, ou `nil` sem nenhuma (para `List(_:children:)`).
    var childrenOrNil: [Note]? {
        let children = sortedChildren
        return children.isEmpty ? nil : children
    }

    /// Páginas acima desta, da raiz até ao pai.
    var ancestors: [Note] {
        var result: [Note] = []
        var current = parent
        while let note = current, !result.contains(where: { $0 === note }) {
            result.insert(note, at: 0)
            current = note.parent
        }
        return result
    }

    /// Para criar páginas com blocos e subpáginas, usar `NoteEditing.makeNote`.
    init(title: String = "", icon: String = "📄") {
        self.title = title
        self.icon = icon
    }
}
