import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct BackupTests {
    /// Uma base com um pouco de tudo, incluindo relações.
    /// O contentor tem de viver tanto quanto o contexto, por isso fica guardado.
    private func makePopulatedContainer() throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try DefaultDataSeeder.seedIfNeeded(in: context)
        let food = try #require(try context.fetch(FetchDescriptor<Mynik.Category>()).first { $0.name == "Alimentação" })
        let account = try #require(try context.fetch(FetchDescriptor<Account>()).first)

        let coffee = FinanceTransaction(title: "Café", amount: 10.99, kind: .expense, category: food, account: account)
        let market = FinanceTransaction(title: "Mercadona", amount: 62.40, kind: .expense, category: food, account: account)
        context.insert(coffee)
        context.insert(market)
        context.insert(Bill(title: "Renda", amount: 750, dueDate: .now, recurrence: .monthly, account: account))

        let project = Project(name: "Mynik")
        context.insert(ProjectTask(title: "Fase 6", project: project))
        let note = Note(title: "Ideias")
        context.insert(note)
        note.linkedProjects = [project]
        note.linkedTransactions = [coffee]
        let block = NoteBlock(kind: .text, text: "Widgets")
        block.note = note
        context.insert(block)

        let car = Vehicle(name: "Ibiza")
        context.insert(car)
        let fuel = FuelEntry(odometer: 1000, quantity: 40, totalCost: 60.5)
        fuel.vehicle = car
        context.insert(fuel)

        let document = PersonalDocument(kind: .passport, number: "X123")
        context.insert(document)
        let photo = DocumentPhoto(imageData: Data([1, 2, 3]))
        photo.document = document
        context.insert(photo)

        context.insert(StoreProduct(shopifyID: "gid://1", title: "Colar", price: 29.9))
        context.insert(Investment(name: "VWCE", kind: .etf, units: 1.5, investedAmount: 150))

        let habit = Habit(name: "Ler", targetPerWeek: 5)
        context.insert(habit)
        context.insert(HabitCheck(day: Calendar.current.startOfDay(for: .now), habit: habit))
        try context.save()
        return container
    }

    private func roundTrip(_ archive: BackupArchive) throws -> BackupArchive {
        try BackupArchive.decode(archive.encoded())
    }

    @Test func jsonRoundTripKeepsExactValues() throws {
        let container = try makePopulatedContainer()
        let context = container.mainContext
        let archive = try BackupService.makeArchive(from: context)
        let decoded = try roundTrip(archive)
        #expect(decoded == archive)
        #expect(decoded.transactions.map(\.amount).sorted() == [10.99, 62.40])
        #expect(decoded.documentPhotos.first?.imageData == Data([1, 2, 3]))
    }

    @Test func importIntoEmptyDeviceRecreatesEverything() throws {
        let sourceContainer = try makePopulatedContainer()
        let source = sourceContainer.mainContext
        let archive = try roundTrip(BackupService.makeArchive(from: source))

        let targetContainer = try ModelContainerFactory.make(inMemory: true)
        let target = targetContainer.mainContext
        let summary = try BackupService.importArchive(archive, into: target)
        #expect(summary.inserted == archive.recordCount)

        let copy = try BackupService.makeArchive(from: target, now: archive.exportedAt)
        #expect(copy.transactions == archive.transactions)
        #expect(copy.notes == archive.notes)
        #expect(copy.fuelEntries == archive.fuelEntries)
        #expect(copy.documentPhotos == archive.documentPhotos)
        #expect(copy.recordCount == archive.recordCount)

        let note = try #require(try target.fetch(FetchDescriptor<Note>()).first)
        #expect(note.linkedProjects?.map(\.name) == ["Mynik"])
        #expect(note.linkedTransactions?.map(\.title) == ["Café"])
        #expect(note.blocks?.map(\.text) == ["Widgets"])
        let coffee = try #require(try target.fetch(FetchDescriptor<FinanceTransaction>()).first { $0.title == "Café" })
        #expect(coffee.category?.name == "Alimentação")
        #expect(coffee.account != nil)

        // Hábitos (v0.7) com as marcações ligadas.
        #expect(copy.habits == archive.habits)
        let habit = try #require(try target.fetch(FetchDescriptor<Habit>()).first)
        #expect(habit.name == "Ler")
        #expect(habit.targetPerWeek == 5)
        #expect(habit.checks?.count == 1)
    }

    @Test func olderBackupsWithoutHabitsStillImport() throws {
        let json = #"{"format":1,"transactions":[]}"#
        let archive = try BackupArchive.decode(Data(json.utf8))
        #expect(archive.habits.isEmpty)
        #expect(archive.habitChecks.isEmpty)
    }

    @Test func importingTwiceCreatesNoDuplicates() throws {
        let container = try makePopulatedContainer()
        let context = container.mainContext
        let archive = try BackupService.makeArchive(from: context)
        let before = archive.recordCount

        let summary = try BackupService.importArchive(archive, into: context)
        #expect(summary.inserted == 0)
        #expect(summary.updated == 0)
        #expect(summary.unchanged == before)
        #expect(try BackupService.makeArchive(from: context).recordCount == before)
    }

    @Test func defaultCategoriesFromAnotherDeviceMergeByName() throws {
        let sourceContainer = try makePopulatedContainer()
        let source = sourceContainer.mainContext
        let archive = try BackupService.makeArchive(from: source)

        // Outro dispositivo com as categorias e a conta iniciais (uids diferentes).
        let targetContainer = try ModelContainerFactory.make(inMemory: true)
        let target = targetContainer.mainContext
        try DefaultDataSeeder.seedIfNeeded(in: target)
        let seededCategories = try target.fetchCount(FetchDescriptor<Mynik.Category>())

        try BackupService.importArchive(archive, into: target)
        #expect(try target.fetchCount(FetchDescriptor<Mynik.Category>()) == seededCategories)
        #expect(try target.fetchCount(FetchDescriptor<Account>()) == 1)
        // As categorias passam a ter o uid do ficheiro: a próxima importação reconhece-as logo.
        let targetUIDs = Set(try target.fetch(FetchDescriptor<Mynik.Category>()).map(\.uid))
        #expect(targetUIDs == Set(archive.categories.map(\.uid)))
    }

    @Test func importUpdatesChangedRecordsAndKeepsLocalOnes() throws {
        let container = try makePopulatedContainer()
        let context = container.mainContext
        var archive = try BackupService.makeArchive(from: context)
        let index = try #require(archive.transactions.firstIndex { $0.title == "Café" })
        archive.transactions[index].amount = 3.20
        archive.transactions[index].categoryUID = nil
        context.insert(FinanceTransaction(title: "Só aqui", amount: 5, kind: .expense))
        try context.save()

        let summary = try BackupService.importArchive(archive, into: context)
        #expect(summary.updated == 1)
        #expect(summary.inserted == 0)
        let transactions = try context.fetch(FetchDescriptor<FinanceTransaction>())
        let coffee = try #require(transactions.first { $0.title == "Café" })
        #expect(coffee.amount == 3.20)
        #expect(coffee.category == nil)
        #expect(transactions.contains { $0.title == "Só aqui" })
    }

    @Test func rejectsInvalidAndNewerFiles() throws {
        #expect(throws: BackupError.unreadable) { try BackupArchive.decode(Data("olá".utf8)) }
        var future = BackupArchive()
        future.format = BackupArchive.currentFormat + 1
        let data = try future.encoded()
        #expect(throws: BackupError.newerFormat) { try BackupArchive.decode(data) }
        // Listas em falta contam como vazias.
        let minimal = try BackupArchive.decode(Data(#"{"format":1}"#.utf8))
        #expect(minimal.recordCount == 0)
    }

    @Test func repairGivesEveryRecordItsOwnUID() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let first = FinanceTransaction(title: "A", amount: 1, kind: .expense)
        let second = FinanceTransaction(title: "B", amount: 2, kind: .expense)
        let third = FinanceTransaction(title: "C", amount: 3, kind: .expense)
        second.uid = first.uid
        third.uid = ""
        [first, second, third].forEach(context.insert)
        try context.save()

        try StableIDRepair.run(in: context)
        let uids = try context.fetch(FetchDescriptor<FinanceTransaction>()).map(\.uid)
        #expect(Set(uids).count == 3)
        #expect(!uids.contains(""))
    }

    /// Uma base de dados da v0.5 (esquema V4) abre na v0.6 e os registos ficam com uids únicos.
    @Test func migratesVersionFourStoreOnDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "mynik-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")

        do {
            let schema = Schema(versionedSchema: MynikSchemaV4.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            for title in ["Renda", "Luz"] {
                let transaction = MynikSchemaV4.FinanceTransaction()
                transaction.title = title
                old.mainContext.insert(transaction)
            }
            let car = MynikSchemaV4.Vehicle()
            car.name = "Ibiza"
            old.mainContext.insert(car)
            try old.mainContext.save()
        }

        let current = try ModelContainerFactory.make(url: url)
        try StableIDRepair.run(in: current.mainContext)
        let transactions = try current.mainContext.fetch(FetchDescriptor<FinanceTransaction>())
        #expect(Set(transactions.map(\.title)) == ["Renda", "Luz"])
        #expect(Set(transactions.map(\.uid)).count == 2)
        #expect(try current.mainContext.fetch(FetchDescriptor<Vehicle>()).map(\.name) == ["Ibiza"])
    }
}
