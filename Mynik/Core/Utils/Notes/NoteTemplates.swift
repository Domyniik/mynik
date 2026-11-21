import Foundation
import SwiftData

/// Template de página incluído na app.
struct BuiltInNoteTemplate: Identifiable, Sendable {
    var id: String
    var title: String
    var icon: String
    var cover: NoteCover?
    /// Conteúdo em Markdown (`{{data}}` vira a data de hoje).
    var markdown: String
    /// Cria uma base de dados com estas propriedades.
    var properties: [NoteProperty]? = nil
}

/// Templates: os da app e páginas guardadas como template.
enum NoteTemplates {
    static let builtIn: [BuiltInNoteTemplate] = [
        BuiltInNoteTemplate(
            id: "meeting", title: "Reunião {{data}}", icon: "🤝", cover: .ocean,
            markdown: """
            ## Participantes
            - 

            ## Pontos
            1. 

            ## Decisões
            <aside>
            ✅ 
            </aside>

            ## Próximos passos
            - [ ] 
            """
        ),
        BuiltInNoteTemplate(
            id: "journal", title: "Diário {{data}}", icon: "📔", cover: .peach,
            markdown: """
            ## Como me sinto
            

            ## Gratidão
            - 

            ## Hoje fiz
            - [ ] 

            > Uma frase para lembrar
            """
        ),
        BuiltInNoteTemplate(
            id: "project", title: "Novo projeto", icon: "🎯", cover: .forest,
            markdown: """
            <aside>
            🎯 Objetivo: 
            </aside>

            ## Contexto
            

            ## Tarefas
            - [ ] 

            ## Orçamento
            | Item | Valor (€) |
            | --- | --- |
            |  |  |

            ---
            ## Notas
            
            """
        ),
        BuiltInNoteTemplate(
            id: "reading", title: "Leituras", icon: "📚", cover: .lavender,
            markdown: "Livros e artigos para ler, a ler e lidos.",
            properties: [
                NoteProperty(name: "Estado", type: .select, options: ["Para ler", "A ler", "Lido"]),
                NoteProperty(name: "Autor", type: .text),
                NoteProperty(name: "Nota", type: .number),
                NoteProperty(name: "Terminado em", type: .date),
            ]
        ),
        BuiltInNoteTemplate(
            id: "week", title: "Semana de {{data}}", icon: "🗓️", cover: .sand,
            markdown: """
            ## Prioridades
            1. 

            ## Segunda
            - [ ] 
            ## Terça
            - [ ] 
            ## Quarta
            - [ ] 
            ## Quinta
            - [ ] 
            ## Sexta
            - [ ] 

            ## Revisão
            
            """
        ),
    ]

    /// Troca `{{data}}` pela data (ex.: "21 nov 2026").
    static func fill(_ text: String, date: Date = .now) -> String {
        text.replacingOccurrences(of: "{{data}}", with: NoteMention.label(for: date))
    }

    /// Cria uma página a partir de um template da app.
    @discardableResult
    static func instantiate(_ template: BuiltInNoteTemplate, parent: Note? = nil, in context: ModelContext, date: Date = .now) -> Note {
        let note: Note
        if let properties = template.properties {
            note = NoteDatabase.makeDatabase(title: fill(template.title, date: date), parent: parent, in: context)
            note.databaseProperties = properties.map { var copy = $0; copy.id = UUID().uuidString; return copy }
        } else {
            note = NoteEditing.makeNote(title: fill(template.title, date: date), parent: parent, in: context)
        }
        note.icon = template.icon
        note.cover = template.cover
        let parsed = NoteMarkdown.parse(fill(template.markdown, date: date)).map { block in
            var block = block
            block.text = block.text.trimmingCharacters(in: .whitespaces)
            return block
        }
        replaceBlocks(of: note, with: parsed, in: context)
        return note
    }

    /// Cria uma página a partir de uma página guardada como template.
    @discardableResult
    static func instantiate(template: Note, parent: Note? = nil, in context: ModelContext, date: Date = .now) -> Note {
        let note = NoteEditing.makeNote(title: fill(template.title, date: date), parent: parent, in: context)
        copyContent(from: template, to: note, in: context, date: date)
        note.isTemplate = false
        return note
    }

    /// Guarda uma cópia da página como template (sem subpáginas nem linhas).
    @discardableResult
    static func saveAsTemplate(_ note: Note, in context: ModelContext) -> Note {
        let template = NoteEditing.makeNote(title: note.title, in: context)
        copyContent(from: note, to: template, in: context, date: nil)
        template.isTemplate = true
        template.isFavorite = false
        return template
    }

    private static func copyContent(from source: Note, to target: Note, in context: ModelContext, date: Date?) {
        target.icon = source.icon
        target.coverRaw = source.coverRaw
        target.isDatabase = source.isDatabase
        target.databaseSchemaJSON = source.databaseSchemaJSON
        target.databaseViewRaw = source.databaseViewRaw
        for block in target.sortedBlocks { NoteEditing.deleteBlock(block, from: target, context: context) }
        var previous: NoteBlock?
        for block in source.sortedBlocks {
            let text = date.map { fill(block.text, date: $0) } ?? block.text
            let copy = NoteEditing.insertBlock(block.kind, text: text, imageData: block.imageData, after: previous, in: target, context: context)
            copy.isChecked = date == nil ? block.isChecked : false
            copy.emoji = block.emoji
            copy.language = block.language
            copy.detail = block.detail
            copy.isExpanded = block.isExpanded
            previous = copy
        }
        if target.blocks?.isEmpty ?? true {
            NoteEditing.insertBlock(.text, in: target, context: context)
        }
    }

    private static func replaceBlocks(of note: Note, with parsed: [NoteMarkdown.ParsedBlock], in context: ModelContext) {
        for block in note.sortedBlocks { NoteEditing.deleteBlock(block, from: note, context: context) }
        NoteEditing.append(parsed.filter { $0.kind != .image }, to: note, context: context)
        if note.blocks?.isEmpty ?? true {
            NoteEditing.insertBlock(.text, in: note, context: context)
        }
    }
}
