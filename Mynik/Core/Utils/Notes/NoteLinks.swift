import Foundation

/// Ligações de uma nota a outras notas, projetos e movimentos.
enum NoteLinks {
    /// Itens mencionados no texto com `[[Título]]`.
    struct Mentions {
        var notes: [Note] = []
        var projects: [Project] = []
        /// Menções sem nota nem projeto com esse nome.
        var unresolved: [String] = []
    }

    /// Resolve as menções `[[…]]` da nota pelo título (sem distinguir maiúsculas):
    /// primeiro notas, depois projetos.
    static func mentions(in note: Note, notes: [Note], projects: [Project]) -> Mentions {
        var result = Mentions()
        for title in NoteMarkdown.mentions(in: note.plainText) {
            if let match = notes.first(where: { $0 !== note && $0.title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(title) == .orderedSame }) {
                result.notes.append(match)
            } else if let match = projects.first(where: { $0.name.caseInsensitiveCompare(title) == .orderedSame }) {
                result.projects.append(match)
            } else {
                result.unresolved.append(title)
            }
        }
        return result
    }

    static func isLinked(_ project: Project, to note: Note) -> Bool {
        note.linkedProjects?.contains { $0 === project } ?? false
    }

    static func isLinked(_ transaction: FinanceTransaction, to note: Note) -> Bool {
        note.linkedTransactions?.contains { $0 === transaction } ?? false
    }

    static func isLinked(_ other: Note, to note: Note) -> Bool {
        note.linkedNotes?.contains { $0 === other } ?? false
    }

    static func toggle(_ project: Project, in note: Note) {
        if isLinked(project, to: note) {
            note.linkedProjects?.removeAll { $0 === project }
        } else {
            note.linkedProjects = (note.linkedProjects ?? []) + [project]
        }
        NoteEditing.touch(note)
    }

    static func toggle(_ transaction: FinanceTransaction, in note: Note) {
        if isLinked(transaction, to: note) {
            note.linkedTransactions?.removeAll { $0 === transaction }
        } else {
            note.linkedTransactions = (note.linkedTransactions ?? []) + [transaction]
        }
        NoteEditing.touch(note)
    }

    /// Liga (ou desliga) outra nota; uma nota não se liga a si própria.
    static func toggle(_ other: Note, in note: Note) {
        guard other !== note else { return }
        if isLinked(other, to: note) {
            note.linkedNotes?.removeAll { $0 === other }
        } else {
            note.linkedNotes = (note.linkedNotes ?? []) + [other]
        }
        NoteEditing.touch(note)
    }
}
