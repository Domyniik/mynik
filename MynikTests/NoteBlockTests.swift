import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct NoteBlockTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
    }

    @Test func slashMenuFiltersWithoutAccentsOrCase() {
        #expect(NoteBlockKind.matching("").count == NoteBlockKind.allCases.count)
        #expect(NoteBlockKind.matching("h2") == [.heading2])
        #expect(NoteBlockKind.matching("CITAÇÃO") == [.quote])
        #expect(NoteBlockKind.matching("codigo").contains(.code))
        #expect(NoteBlockKind.matching("tab").contains(.table))
        #expect(NoteBlockKind.matching("zzz").isEmpty)
    }

    @Test func codeFenceAndDividerShortcuts() {
        #expect(NoteMarkdown.shortcut(for: "---")?.kind == .divider)
        #expect(NoteMarkdown.shortcut(for: "```swift") == .init(kind: .code, text: "", language: "swift"))
    }

    @Test func parsesRichMarkdown() {
        let markdown = """
        ## Secção
        - um
        2. dois
        > citação
        > continua

        ```swift
        let x = 1
        print(x)
        ```

        <aside>
        ⚠️ Atenção aqui
        </aside>

        | Nome | Valor |
        | --- | --- |
        | A | 1 |

        ---
        ![Foto bonita](Pasta/foto%201.png)
        """
        #expect(NoteMarkdown.parse(markdown) == [
            .init(kind: .heading2, text: "Secção"),
            .init(kind: .bulleted, text: "um"),
            .init(kind: .numbered, text: "dois"),
            .init(kind: .quote, text: "citação\ncontinua"),
            .init(kind: .code, text: "let x = 1\nprint(x)", language: "swift"),
            .init(kind: .callout, text: "Atenção aqui", emoji: "⚠️"),
            .init(kind: .table, text: "Nome\tValor\nA\t1"),
            .init(kind: .divider, text: ""),
            .init(kind: .image, text: "Foto bonita", imagePath: "Pasta/foto 1.png"),
        ])
    }

    @Test func exportsAndReparsesNewBlocks() {
        let code = NoteBlock(kind: .code, text: "ls -la")
        code.language = "bash"
        let callout = NoteBlock(kind: .callout, text: "Lembrete")
        callout.emoji = "📌"
        let blocks = [
            NoteBlock(kind: .numbered, text: "A"), NoteBlock(kind: .numbered, text: "B"),
            NoteBlock(kind: .quote, text: "Q"), code, callout,
            NoteBlock(kind: .table, text: "x\ty\n1\t2"), NoteBlock(kind: .divider),
        ]
        let markdown = NoteMarkdown.export(title: "T", blocks: blocks)
        #expect(markdown.contains("1. A\n2. B"))
        #expect(markdown.contains("```bash\nls -la\n```"))
        #expect(markdown.contains("| x | y |\n| --- | --- |\n| 1 | 2 |"))
        let parsed = NoteMarkdown.parse(markdown).dropFirst()  // título da página
        #expect(parsed.map(\.kind) == [.numbered, .numbered, .quote, .code, .callout, .table, .divider])
    }

    @Test func tableEditing() {
        var table = NoteTable(text: "")
        #expect(table.rows == [["", ""], ["", ""]])
        table.addColumn()
        table.addRow()
        table.rows[0][2] = "C"
        #expect(table.columnCount == 3)
        #expect(table.rows.count == 3)
        table.removeColumn(at: 0)
        table.removeRow(at: 2)
        #expect(table.text == "\tC\n\t")
        #expect(NoteTable(text: "a\tb\nc").rows == [["a", "b"], ["c", ""]])
    }

    @Test func numberedListsRestartAfterOtherBlocks() {
        let blocks = [
            NoteBlock(kind: .numbered), NoteBlock(kind: .numbered), NoteBlock(kind: .text), NoteBlock(kind: .numbered),
        ]
        let numbers = NoteEditing.listNumbers(for: blocks)
        #expect(blocks.map { numbers[$0.uid] } == [1, 2, nil, 1])
    }

    @Test func slashCommandTransformsBlock() throws {
        let note = NoteEditing.makeNote(title: "P", in: context)
        let block = try #require(note.sortedBlocks.first)
        block.text = "/div"
        let focused = NoteEditing.applySlashCommand(.divider, to: block, in: note, context: context)
        #expect(block.kind == .divider)
        #expect(note.sortedBlocks.map(\.kind) == [.divider, .text])
        #expect(focused === note.sortedBlocks.last)

        let next = try #require(focused)
        next.text = "/h1"
        NoteEditing.applySlashCommand(.heading, to: next, in: note, context: context)
        #expect(next.kind == .heading)
        #expect(next.text.isEmpty)
    }

    @Test func recordsCarryNewFieldsAndReadOldPayloads() throws {
        let block = NoteBlock(kind: .toggle, text: "Mais")
        block.detail = "escondido"
        block.isExpanded = true
        context.insert(block)
        let record = NoteBlockRecord(block)
        let copy = NoteBlock(kind: .text)
        record.apply(to: copy)
        #expect(copy.kind == .toggle && copy.detail == "escondido" && copy.isExpanded)

        // Registo da v1.3 (sem os campos novos).
        let old = #"{"uid":"a","kindRaw":"text","text":"x","isChecked":false,"sortOrder":0,"createdAt":0}"#
        let decoded = try JSONDecoder().decode(NoteBlockRecord.self, from: Data(old.utf8))
        decoded.apply(to: copy)
        #expect(copy.emoji == "💡" && copy.detail.isEmpty && !copy.isExpanded)

        let oldNote = #"{"uid":"n","title":"T","icon":"📄","createdAt":0,"updatedAt":0,"sortOrder":0,"linkedProjectUIDs":[],"linkedTransactionUIDs":[],"linkedNoteUIDs":[]}"#
        let note = Note()
        try JSONDecoder().decode(NoteRecord.self, from: Data(oldNote.utf8)).apply(to: note)
        #expect(!note.isFavorite && !note.isDatabase && note.databaseViewRaw == "table")
    }

    @Test func migratesVersionSixStoreOnDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "mynik-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")

        do {
            let schema = Schema(versionedSchema: MynikSchemaV6.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let note = MynikSchemaV6.Note()
            note.uid = "n1"
            note.title = "Antiga"
            let block = MynikSchemaV6.NoteBlock()
            block.kindRaw = "heading"
            block.text = "Título"
            old.mainContext.insert(note)
            old.mainContext.insert(block)
            block.note = note
            try old.mainContext.save()
        }

        let current = try ModelContainerFactory.make(url: url)
        let notes = try current.mainContext.fetch(FetchDescriptor<Note>())
        #expect(notes.map(\.uid) == ["n1"])
        #expect(notes.first?.isDatabase == false)
        #expect(notes.first?.sortedBlocks.first?.kind == .heading)
        #expect(notes.first?.sortedBlocks.first?.emoji == "💡")
    }
}

@MainActor
struct NoteBlockReorderTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
    }

    @Test func movesDuplicatesAndKeepsOrderContiguous() throws {
        let note = NoteEditing.makeNote(title: "P", in: context)
        let first = try #require(note.sortedBlocks.first)
        first.text = "A"
        let second = NoteEditing.insertBlock(.code, text: "B", in: note, context: context)
        second.language = "swift"
        NoteEditing.insertBlock(.text, text: "C", in: note, context: context)

        NoteEditing.moveBlock(second, by: -1, in: note)
        #expect(note.sortedBlocks.map(\.text) == ["B", "A", "C"])
        NoteEditing.moveBlock(second, by: -1, in: note)  // já está no topo
        #expect(note.sortedBlocks.map(\.text) == ["B", "A", "C"])

        let copy = NoteEditing.duplicateBlock(second, in: note, context: context)
        #expect(note.sortedBlocks.map(\.text) == ["B", "B", "A", "C"])
        #expect(copy.kind == .code && copy.language == "swift" && copy !== second)

        NoteEditing.moveBlocks(in: note, from: [3], to: 0)
        #expect(note.sortedBlocks.map(\.text) == ["C", "B", "B", "A"])
        #expect(note.sortedBlocks.map(\.sortOrder) == [0, 1, 2, 3])
    }
}
