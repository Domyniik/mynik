import Foundation
import SwiftData
import Testing
@testable import Mynik

/// Servidor em memória com as mesmas regras das tabelas do Supabase:
/// uma linha por (entity, key), last-write-wins por `modifiedAt` e `updatedAt` do servidor.
actor FakeSyncRemote: SyncRemote {
    private(set) var rows: [String: SyncRow] = [:]
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private(set) var pushCount = 0

    func pull(since: Date?) async throws -> [SyncRow] {
        rows.values
            .filter { since == nil || $0.updatedAt! >= since! }
            .sorted { $0.updatedAt! < $1.updatedAt! }
    }

    func push(_ incoming: [SyncRow]) async throws {
        pushCount += 1
        for var row in incoming {
            let id = "\(row.entity)/\(row.key)"
            if let existing = rows[id], existing.modifiedAt > row.modifiedAt { continue }
            clock = clock.addingTimeInterval(10)
            row.updatedAt = clock
            rows[id] = row
        }
    }

    func row(_ entity: SyncEntity, _ key: String) -> SyncRow? { rows["\(entity.rawValue)/\(key)"] }
}

/// Um dispositivo: base SwiftData própria e estado de sync próprio.
@MainActor
final class FakeDevice {
    let container: ModelContainer
    let engine: SyncEngine
    /// Preferências próprias do dispositivo (definições partilhadas).
    let defaults: UserDefaults
    var context: ModelContext { container.mainContext }

    init(remote: FakeSyncRemote) throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
        let url = URL.temporaryDirectory.appending(path: "sync-\(UUID().uuidString).json")
        defaults = UserDefaults(suiteName: "sync-device-\(UUID().uuidString)") ?? .standard
        engine = SyncEngine(remote: remote, store: SyncStateStore(url: url), settings: defaults)
    }

    @discardableResult
    func sync(at now: Date = .now) async throws -> SyncReport {
        try await engine.sync(context: context, userID: "user-1", now: now)
    }

    func transactions() throws -> [FinanceTransaction] {
        try context.fetch(FetchDescriptor<FinanceTransaction>())
    }
}

@MainActor
struct SyncTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Um registo criado no Mac aparece no iPhone, com a categoria certa")
    func createdOnOneDeviceAppearsOnTheOther() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        try await mac.sync(at: t0)
        try await iPhone.sync(at: t0)

        let food = try #require(try mac.context.fetch(FetchDescriptor<Mynik.Category>()).first { $0.name == "Alimentação" })
        mac.context.insert(FinanceTransaction(title: "Café", amount: 1.35, kind: .expense, category: food))
        try mac.context.save()
        try await mac.sync(at: t0 + 60)
        try await iPhone.sync(at: t0 + 120)

        let coffee = try #require(try iPhone.transactions().first { $0.title == "Café" })
        #expect(coffee.amount == Decimal(string: "1.35"))
        #expect(coffee.category?.name == "Alimentação")
        // As categorias iniciais de cada dispositivo juntam-se pelo nome: sem duplicados.
        let names = try iPhone.context.fetch(FetchDescriptor<Mynik.Category>()).map(\.name)
        #expect(names.count == Set(names).count)
    }

    @Test("E vice-versa: o iPhone também envia para o Mac")
    func worksInBothDirections() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        try await mac.sync(at: t0)
        try await iPhone.sync(at: t0)

        iPhone.context.insert(Project(name: "Viagem"))
        try iPhone.context.save()
        try await iPhone.sync(at: t0 + 60)
        try await mac.sync(at: t0 + 120)

        #expect(try mac.context.fetch(FetchDescriptor<Project>()).map(\.name) == ["Viagem"])
    }

    @Test("Apagar envia um tombstone que apaga no outro dispositivo e não ressuscita")
    func deletionPropagatesAsTombstone() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        let rent = Bill(title: "Renda", amount: 750, dueDate: t0)
        mac.context.insert(rent)
        try mac.context.save()
        let uid = rent.uid
        try await mac.sync(at: t0)
        try await iPhone.sync(at: t0 + 10)
        #expect(try iPhone.context.fetch(FetchDescriptor<Bill>()).count == 1)

        mac.context.delete(rent)
        try mac.context.save()
        try await mac.sync(at: t0 + 60)
        let tombstone = try #require(await remote.row(.bill, uid))
        #expect(tombstone.deleted)
        #expect(tombstone.payload == nil)

        let report = try await iPhone.sync(at: t0 + 120)
        #expect(report.deletedLocally == 1)
        #expect(try iPhone.context.fetch(FetchDescriptor<Bill>()).isEmpty)

        // Novos syncs dos dois lados não a trazem de volta.
        try await iPhone.sync(at: t0 + 180)
        try await mac.sync(at: t0 + 240)
        #expect(try mac.context.fetch(FetchDescriptor<Bill>()).isEmpty)
        #expect(try iPhone.context.fetch(FetchDescriptor<Bill>()).isEmpty)
        #expect(try #require(await remote.row(.bill, uid)).deleted)
    }

    @Test("Conflito: a alteração mais recente ganha (last-write-wins)")
    func lastWriteWins() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        let task = ProjectTask(title: "Original")
        mac.context.insert(task)
        try mac.context.save()
        try await mac.sync(at: t0)
        try await iPhone.sync(at: t0 + 10)

        // Os dois editam sem rede; o iPhone edita depois.
        task.title = "Do Mac"
        try mac.context.save()
        let onPhone = try #require(try iPhone.context.fetch(FetchDescriptor<ProjectTask>()).first)
        onPhone.title = "Do iPhone"
        try iPhone.context.save()

        try await iPhone.sync(at: t0 + 120) // mais recente, envia primeiro
        try await mac.sync(at: t0 + 60)     // mais antigo: perde e recebe a versão do iPhone
        try await iPhone.sync(at: t0 + 180)

        #expect(task.title == "Do iPhone")
        #expect(try iPhone.context.fetch(FetchDescriptor<ProjectTask>()).first?.title == "Do iPhone")
    }

    @Test("A alteração local mais recente sobrevive ao pull e é enviada")
    func newerLocalChangeSurvivesPull() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        let goal = Goal(title: "Fundo", targetAmount: 1000)
        mac.context.insert(goal)
        try mac.context.save()
        try await mac.sync(at: t0)
        try await iPhone.sync(at: t0 + 10)

        let onPhone = try #require(try iPhone.context.fetch(FetchDescriptor<Goal>()).first)
        onPhone.targetAmount = 2000
        try iPhone.context.save()
        try await iPhone.sync(at: t0 + 60)

        goal.targetAmount = 3000         // editado no Mac depois do iPhone
        try mac.context.save()
        try await mac.sync(at: t0 + 120)
        #expect(goal.targetAmount == 3000)

        try await iPhone.sync(at: t0 + 180)
        #expect(onPhone.targetAmount == 3000)
    }

    @Test("Apagar perde para uma edição mais recente noutro dispositivo")
    func newerEditBeatsOlderTombstone() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        let car = Vehicle(name: "Ibiza")
        mac.context.insert(car)
        try mac.context.save()
        try await mac.sync(at: t0)
        try await iPhone.sync(at: t0 + 10)

        let onPhone = try #require(try iPhone.context.fetch(FetchDescriptor<Vehicle>()).first)
        onPhone.name = "Ibiza FR"
        try iPhone.context.save()
        mac.context.delete(car)
        try mac.context.save()

        try await iPhone.sync(at: t0 + 120) // edição mais recente
        try await mac.sync(at: t0 + 60)     // tombstone mais antigo: o servidor recusa e o carro volta
        #expect(try mac.context.fetch(FetchDescriptor<Vehicle>()).map(\.name) == ["Ibiza FR"])
    }

    @Test("Sem alterações não se envia nada")
    func idleSyncPushesNothing() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        try await mac.sync(at: t0)
        let before = await remote.pushCount
        let report = try await mac.sync(at: t0 + 60)
        #expect(report == SyncReport())
        #expect(await remote.pushCount == before)
    }

    @Test("No primeiro sync de um dispositivo, o servidor ganha nos registos que já lá estão")
    func firstSyncPrefersServer() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        let course = Course(title: "Swift")
        mac.context.insert(course)
        try mac.context.save()
        // O iPhone tem uma cópia antiga (importada de um backup) do mesmo curso.
        try BackupService.importArchive(try BackupService.makeArchive(from: mac.context), into: iPhone.context)
        course.title = "Swift 6"
        try mac.context.save()

        try await mac.sync(at: t0)
        try await iPhone.sync(at: t0 + 3600)
        #expect(try iPhone.context.fetch(FetchDescriptor<Course>()).map(\.title) == ["Swift 6"])
    }

    @Test("As fotos dos documentos nunca vão para o servidor")
    func documentPhotosStayLocal() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let document = PersonalDocument(kind: .passport, number: "X123")
        mac.context.insert(document)
        let photo = DocumentPhoto(imageData: Data([1, 2, 3]))
        photo.document = document
        mac.context.insert(photo)
        try mac.context.save()
        try await mac.sync(at: t0)

        let rows = await remote.rows.values
        #expect(rows.contains { $0.entity == SyncEntity.document.rawValue })
        #expect(!rows.contains { $0.entity.localizedCaseInsensitiveContains("photo") })
        #expect(!rows.contains { String(decoding: $0.payload ?? Data(), as: UTF8.self).contains("imageData") })
    }

    @Test("Deteção de alterações: novo, alterado e apagado ficam por enviar")
    func markLocalChanges() {
        var state = SyncState()
        state.entries["bill/a"] = .init(hash: "1", modifiedAt: t0, dirty: false)
        state.entries["bill/b"] = .init(hash: "2", modifiedAt: t0, dirty: false)
        state.entries["bill/c"] = .init(hash: "3", modifiedAt: t0, dirty: false)
        let local: [String: SyncEngine.LocalRecord] = [
            "bill/a": .init(data: Data(), hash: "1"),   // igual
            "bill/b": .init(data: Data(), hash: "2b"),  // alterado
            "bill/d": .init(data: Data(), hash: "4"),   // novo
        ]                                                // c: apagado
        let now = t0 + 60
        SyncEngine.markLocalChanges(local, in: &state, at: now)

        #expect(state.entries["bill/a"] == .init(hash: "1", modifiedAt: t0, dirty: false))
        #expect(state.entries["bill/b"] == .init(hash: "2b", modifiedAt: now, dirty: true))
        #expect(state.entries["bill/c"] == .init(hash: nil, modifiedAt: now, dirty: true))
        #expect(state.entries["bill/d"] == .init(hash: "4", modifiedAt: now, dirty: true))
    }

    @Test("Chave de estado com barras (ids da Shopify) separa-se bem")
    func stateKeyRoundTrip() throws {
        let key = SyncState.key(.storeProduct, "gid://shopify/Product/1")
        let (entity, id) = try #require(SyncState.split(key))
        #expect(entity == .storeProduct)
        #expect(id == "gid://shopify/Product/1")
    }

    @Test("Timestamps do Postgres com microssegundos e fuso")
    func postgresTimestamps() throws {
        let date = try #require(PostgresTimestamp.date(from: "2026-11-21T15:07:38.123456+00:00"))
        #expect(abs(date.timeIntervalSince1970 - 1_795_273_658.123456) < 0.000_01)
        #expect(PostgresTimestamp.date(from: "2026-11-21T15:07:38+00:00")?.timeIntervalSince1970 == 1_795_273_658)
        let roundTrip = try #require(PostgresTimestamp.date(from: PostgresTimestamp.string(from: date)))
        #expect(abs(roundTrip.timeIntervalSince(date)) < 0.001)
    }

    @Test("O payload passa pelo jsonb sem arredondar valores em euros")
    func rawJSONKeepsDecimals() throws {
        let record = TransactionRecord(
            uid: "a", title: "Café", amount: Decimal(string: "0.1")! + Decimal(string: "0.2")!,
            kindRaw: "expense", currencyCode: "EUR", date: t0, notes: "", createdAt: t0,
            externalID: "", categoryUID: nil, accountUID: "b"
        )
        let data = try SyncEntity.canonicalJSON(record)
        let back = try RawJSON(data: data).data()
        var archive = BackupArchive()
        let canonical = try SyncEntity.transaction.append(back, to: &archive)
        #expect(canonical == data)
        #expect(archive.transactions.first?.amount == Decimal(string: "0.3"))
        #expect(try RawJSON(data: Data("[true,1,null]".utf8)) == .array([.bool(true), .number(1), .null]))
    }

    @Test("Definições partilhadas (custos da loja, taxa BRL) passam para o outro dispositivo")
    func sharedSettingsSync() async throws {
        let remote = FakeSyncRemote()
        let mac = try FakeDevice(remote: remote)
        let iPhone = try FakeDevice(remote: remote)
        mac.defaults.set(3.5, forKey: SettingsKey.storeFeePercent)
        mac.defaults.set(6.25, forKey: SettingsKey.brlPerEUR)
        mac.defaults.set(true, forKey: SettingsKey.appLockEnabled) // do dispositivo: não vai
        try await mac.sync(at: t0)
        #expect(await remote.row(.setting, SettingsKey.storeFeePercent) != nil)
        #expect(await remote.row(.setting, SettingsKey.appLockEnabled) == nil)

        try await iPhone.sync(at: t0.addingTimeInterval(60))
        #expect(iPhone.defaults.double(forKey: SettingsKey.storeFeePercent) == 3.5)
        #expect(iPhone.defaults.double(forKey: SettingsKey.brlPerEUR) == 6.25)
        #expect(iPhone.defaults.object(forKey: SettingsKey.appLockEnabled) == nil)

        // Mudar no iPhone chega ao Mac.
        iPhone.defaults.set(4.0, forKey: SettingsKey.storeShippingCost)
        try await iPhone.sync(at: t0.addingTimeInterval(120))
        try await mac.sync(at: t0.addingTimeInterval(180))
        #expect(mac.defaults.double(forKey: SettingsKey.storeShippingCost) == 4)
    }

    @Test("A cópia de segurança leva as definições só quando pedido e lê cópias sem elas")
    func backupSettings() throws {
        let device = try FakeDevice(remote: FakeSyncRemote())
        device.defaults.set(250.0, forKey: SettingsKey.savingsMonthlyTarget)
        #expect(try BackupService.makeArchive(from: device.context).settings == nil)
        let archive = try BackupService.makeArchive(from: device.context, settings: device.defaults)
        #expect(archive.settings == [SettingRecord(key: SettingsKey.savingsMonthlyTarget, value: .number(250))])

        let other = try FakeDevice(remote: FakeSyncRemote())
        let copy = try BackupArchive.decode(archive.encoded())
        try BackupService.importArchive(copy, into: other.context, settings: other.defaults)
        #expect(other.defaults.double(forKey: SettingsKey.savingsMonthlyTarget) == 250)
    }
}
