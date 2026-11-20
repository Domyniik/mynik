import Foundation
import SwiftData
import Testing
@testable import Mynik

struct NoteMarkdownTests {
    @Test func findsMentionsOncePerTitle() {
        let text = "Ver [[Fornecedores]] e [[ Viagem ]]. Outra vez [[fornecedores]]. [[]] não conta."
        #expect(NoteMarkdown.mentions(in: text) == ["Fornecedores", "Viagem"])
    }

    @Test func rendersInlineMarkdownAndMentionLinks() {
        let rendered = NoteMarkdown.attributed("Texto **forte** com [[Casa Nova]]")
        #expect(String(rendered.characters) == "Texto forte com Casa Nova")
        let link = rendered.runs.compactMap(\.link).first
        #expect(link?.scheme == "mynik")
        #expect(link?.absoluteString.hasSuffix("Casa%20Nova") == true)
        let strong = rendered.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        #expect(strong.map { String(rendered[$0.range].characters) } == "forte")
    }

    @Test(arguments: [
        ("# Plano", NoteBlockKind.heading, "Plano", false),
        ("## Plano", .heading, "Plano", false),
        ("- [ ] Pão", .checklist, "Pão", false),
        ("- [x] Leite", .checklist, "Leite", true),
        ("[] Ovos", .checklist, "Ovos", false),
    ])
    func typingShortcutsChangeBlockKind(input: String, kind: NoteBlockKind, text: String, checked: Bool) {
        #expect(NoteMarkdown.shortcut(for: input) == .init(kind: kind, text: text, isChecked: checked))
    }

    @Test func plainTextIsNotAShortcut() {
        #expect(NoteMarkdown.shortcut(for: "#hashtag") == nil)
        #expect(NoteMarkdown.shortcut(for: "- lista normal") == nil)
    }

    @Test func parsesMarkdownIntoBlocks() {
        let markdown = """
        # Compras
        Lista para o fim de semana,
        sem esquecer nada.

        - [ ] Pão
        - [x] Leite

        Fim.
        """
        #expect(NoteMarkdown.parse(markdown) == [
            .init(kind: .heading, text: "Compras"),
            .init(kind: .text, text: "Lista para o fim de semana,\nsem esquecer nada."),
            .init(kind: .checklist, text: "Pão"),
            .init(kind: .checklist, text: "Leite", isChecked: true),
            .init(kind: .text, text: "Fim."),
        ])
    }

    @Test func exportsBlocksAsMarkdown() {
        let blocks = [
            NoteBlock(kind: .text, text: "Olá"),
            NoteBlock(kind: .heading, text: "Tarefas"),
            NoteBlock(kind: .checklist, text: "A"),
            NoteBlock(kind: .checklist, text: "B", isChecked: true),
            NoteBlock(kind: .image, text: "Foto"),
        ]
        #expect(NoteMarkdown.export(title: "Página", blocks: blocks) == """
        # Página

        Olá

        ## Tarefas

        - [ ] A
        - [x] B

        ![Foto](imagem)

        """)
    }
}

@MainActor
struct NoteLinkTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
    }

    @Test func resolvesMentionsToNotesThenProjects() throws {
        let note = NoteEditing.makeNote(title: "Diário", in: context)
        note.sortedBlocks[0].text = "Falar de [[fornecedores]], do [[Mynik]] e de [[Nada]]. [[Diário]]"
        let suppliers = NoteEditing.makeNote(title: "Fornecedores", in: context)
        let project = Project(name: "Mynik")
        context.insert(project)
        try context.save()

        let mentions = NoteLinks.mentions(in: note, notes: [note, suppliers], projects: [project])
        #expect(mentions.notes.map(\.title) == ["Fornecedores"])
        #expect(mentions.projects.map(\.name) == ["Mynik"])
        #expect(mentions.unresolved == ["Nada", "Diário"], "Uma nota não se menciona a si própria")
    }

    @Test func linksWorkInBothDirections() throws {
        let note = NoteEditing.makeNote(title: "Reunião", in: context)
        let other = NoteEditing.makeNote(title: "Ata", in: context)
        let project = Project(name: "Loja")
        let expense = FinanceTransaction(title: "Fotógrafo", amount: 120, kind: .expense)
        context.insert(project)
        context.insert(expense)

        NoteLinks.toggle(project, in: note)
        NoteLinks.toggle(expense, in: note)
        NoteLinks.toggle(other, in: note)
        NoteLinks.toggle(note, in: note)
        try context.save()

        #expect(project.linkedNotes?.map(\.title) == ["Reunião"])
        #expect(expense.linkedNotes?.map(\.title) == ["Reunião"])
        #expect(other.backlinks?.map(\.title) == ["Reunião"])
        #expect(note.linkedNotes?.count == 1)

        NoteLinks.toggle(project, in: note)
        try context.save()
        #expect(!NoteLinks.isLinked(project, to: note))
        #expect(project.linkedNotes?.isEmpty == true)
    }

    @Test func deletingALinkedItemKeepsTheNote() throws {
        let note = NoteEditing.makeNote(title: "Orçamento", in: context)
        let expense = FinanceTransaction(title: "Material", amount: 40, kind: .expense)
        let project = Project(name: "Obras")
        context.insert(expense)
        context.insert(project)
        NoteLinks.toggle(expense, in: note)
        NoteLinks.toggle(project, in: note)
        try context.save()

        context.delete(expense)
        context.delete(project)
        try context.save()

        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.map(\.title) == ["Orçamento"])
        #expect(notes.first?.linkedTransactions?.isEmpty == true)
        #expect(notes.first?.linkedProjects?.isEmpty == true)

        context.delete(note)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 0)
    }
}
