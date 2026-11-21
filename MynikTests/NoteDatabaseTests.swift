import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct NoteDatabaseTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
    }

    @Test func newDatabaseHasStatusAndDate() throws {
        let database = NoteDatabase.makeDatabase(title: "Leituras", in: context)
        #expect(database.isDatabase)
        #expect(database.databaseProperties.map(\.type) == [.select, .date])
        #expect(database.databaseView == .table)
        #expect(database.childrenOrNil == nil)
    }

    @Test func rowValuesAreStoredPerProperty() throws {
        let database = NoteDatabase.makeDatabase(title: "Tarefas", in: context)
        let status = try #require(NoteDatabase.boardProperty(of: database))
        let price = NoteDatabase.addProperty(.number, named: "Preço", to: database)
        let row = NoteDatabase.addRow(to: database, title: "Livro", values: [status.id: "Em curso"], in: context)
        row.setValue("12,5", for: price)
        #expect(row.value(for: status) == "Em curso")
        #expect(NoteDatabase.number(from: row.value(for: price)) == Decimal(string: "12.5"))
        #expect(row.database === database)
        // Valores vazios não ficam guardados.
        row.setValue("", for: price)
        #expect(row.propertyValues[price.id] == nil)

        NoteDatabase.removeProperty(status, from: database)
        #expect(row.propertyValues.isEmpty)
        #expect(!database.databaseProperties.contains { $0.id == status.id })
    }

    @Test func boardGroupsRowsByFirstSelect() throws {
        let database = NoteDatabase.makeDatabase(title: "Kanban", in: context)
        let status = try #require(NoteDatabase.boardProperty(of: database))
        NoteDatabase.addRow(to: database, title: "A", values: [status.id: "Feito"], in: context)
        NoteDatabase.addRow(to: database, title: "B", in: context)
        NoteDatabase.addRow(to: database, title: "C", values: [status.id: "A fazer"], in: context)

        let columns = NoteDatabase.boardColumns(of: database, by: status)
        #expect(columns.map(\.option) == ["", "A fazer", "Em curso", "Feito"])
        #expect(columns.map { $0.rows.map(\.title) } == [["B"], ["C"], [], ["A"]])
    }

    @Test func calendarFindsRowsByDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let database = NoteDatabase.makeDatabase(title: "Agenda", in: context)
        let date = try #require(NoteDatabase.dateProperty(of: database))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 21)))
        NoteDatabase.addRow(to: database, title: "Feira", values: [date.id: "2026-11-21"], in: context)

        #expect(NoteDatabase.dateValue(day, calendar: calendar) == "2026-11-21")
        #expect(NoteDatabase.date(from: "2026-11-21", calendar: calendar) == day)
        #expect(NoteDatabase.rows(of: database, on: day, by: date, calendar: calendar).map(\.title) == ["Feira"])

        let grid = NoteDatabase.monthGrid(for: day, calendar: calendar)
        #expect(grid.count % 7 == 0)
        #expect(calendar.component(.weekday, from: try #require(grid.first)) == 2)  // segunda-feira
        #expect(grid.contains { calendar.isDate($0, inSameDayAs: day) })
    }

    @Test func databaseSurvivesBackupRecord() throws {
        let database = NoteDatabase.makeDatabase(title: "Filmes", in: context)
        database.databaseView = .board
        let row = NoteDatabase.addRow(to: database, title: "Dune", in: context)
        row.setValue("2026-01-02", for: try #require(NoteDatabase.dateProperty(of: database)))

        let copy = Note()
        NoteRecord(database).apply(to: copy)
        #expect(copy.isDatabase && copy.databaseView == .board)
        #expect(copy.databaseProperties == database.databaseProperties)
        let rowCopy = Note()
        NoteRecord(row).apply(to: rowCopy)
        #expect(rowCopy.propertyValues == row.propertyValues)
    }
}

@MainActor
struct NoteSyncPayloadTests {
    @Test func syncPayloadCarriesNotesV7Fields() throws {
        let source = try ModelContainerFactory.make(inMemory: true)
        let database = NoteDatabase.makeDatabase(title: "Filmes", in: source.mainContext)
        database.isFavorite = true
        database.cover = .forest
        let row = NoteDatabase.addRow(to: database, title: "Dune", in: source.mainContext)
        row.setValue("Feito", for: try #require(NoteDatabase.boardProperty(of: database)))
        let callout = NoteEditing.insertBlock(.callout, text: "Ver", in: row, context: source.mainContext)
        callout.emoji = "🎬"
        try source.mainContext.save()

        let archive = try BackupService.makeArchive(from: source.mainContext)
        let notePayload = try #require(try SyncEntity.note.payloads(in: archive)[database.uid])
        let json = try #require(String(data: notePayload, encoding: .utf8))
        #expect(json.contains("\"isDatabase\":true") && json.contains("\"coverRaw\":\"forest\""))
        let blockPayload = try #require(try SyncEntity.noteBlock.payloads(in: archive)[callout.uid])
        #expect(String(data: blockPayload, encoding: .utf8)?.contains("🎬") == true)

        // Outro dispositivo recebe tudo pelo mesmo caminho do sync (registos da cópia).
        let target = try ModelContainerFactory.make(inMemory: true)
        try BackupService.importArchive(archive, into: target.mainContext)
        let imported = try target.mainContext.fetch(FetchDescriptor<Note>()).first { $0.uid == database.uid }
        #expect(imported?.isDatabase == true && imported?.cover == .forest && imported?.isFavorite == true)
        #expect(imported?.sortedChildren.first?.propertyValues == row.propertyValues)
    }
}
