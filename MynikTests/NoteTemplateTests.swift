import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct NoteTemplateTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
    }

    @Test func parsesEmptyListItems() {
        #expect(NoteMarkdown.parse("-\n1.\n- [ ]").map(\.kind) == [.bulleted, .numbered, .checklist])
    }

    @Test func meetingTemplateFillsDateAndBlocks() throws {
        let template = try #require(NoteTemplates.builtIn.first { $0.id == "meeting" })
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 12)))
        let note = NoteTemplates.instantiate(template, in: context, date: date)
        #expect(note.title.hasPrefix("Reunião 21"))
        #expect(!note.title.contains("{{"))
        #expect(note.cover == .ocean)
        let kinds = note.sortedBlocks.map(\.kind)
        #expect(kinds.first == .heading2)
        #expect(kinds.contains(.callout) && kinds.contains(.checklist) && kinds.contains(.numbered))
        #expect(note.sortedBlocks.allSatisfy { !$0.text.hasPrefix("-") })
    }

    @Test func everyBuiltInTemplateInstantiates() {
        for template in NoteTemplates.builtIn {
            let note = NoteTemplates.instantiate(template, in: context)
            #expect(!(note.blocks?.isEmpty ?? true), "\(template.id)")
            #expect(note.isDatabase == (template.properties != nil))
        }
        let reading = NoteTemplates.instantiate(NoteTemplates.builtIn.first { $0.id == "reading" }!, in: context)
        #expect(reading.databaseProperties.map(\.name) == ["Estado", "Autor", "Nota", "Terminado em"])
    }

    @Test func savesAndReusesUserTemplates() throws {
        let source = NoteEditing.makeNote(title: "Checklist de viagem", in: context)
        source.icon = "✈️"
        source.cover = .aurora
        let item = NoteEditing.insertBlock(.checklist, text: "Passaporte", in: source, context: context)
        item.isChecked = true
        NoteEditing.makeNote(title: "Subpágina", parent: source, in: context)

        let template = NoteTemplates.saveAsTemplate(source, in: context)
        #expect(template.isTemplate && template.parent == nil)
        #expect(template.children?.isEmpty ?? true)
        #expect(template.sortedBlocks.map(\.text) == source.sortedBlocks.map(\.text))

        let page = NoteTemplates.instantiate(template: template, in: context)
        #expect(!page.isTemplate)
        #expect(page.icon == "✈️" && page.cover == .aurora)
        // Uma página nova começa com as tarefas por fazer.
        #expect(page.sortedBlocks.first { $0.kind == .checklist }?.isChecked == false)
    }
}
