import Foundation
import SwiftData

/// Tipos de dados sincronizados com o Supabase.
///
/// Cada registo vai para a tabela `records` com `entity` igual ao `rawValue`
/// (estável: não mudar) e o registo da cópia de segurança como `payload`.
/// As fotos dos documentos ficam de fora: nunca saem do dispositivo.
nonisolated enum SyncEntity: String, CaseIterable, Codable, Sendable {
    case category, account, transaction, bill
    case storeProduct, storeOrder, storeCheckout, dailyStat
    case project, task, goal, note, noteBlock
    case vehicle, fuelEntry, maintenance, carDeadline
    case document, jobApplication, course
    case investment, wealthSnapshot
    case habit, habitCheck

    // MARK: - Registo ⇄ JSON

    /// Todos os registos deste tipo na cópia, em JSON canónico, indexados pela chave.
    func payloads(in archive: BackupArchive) throws -> [String: Data] {
        switch self {
        case .category: try Self.encode(archive.categories, key: \.uid)
        case .account: try Self.encode(archive.accounts, key: \.uid)
        case .transaction: try Self.encode(archive.transactions, key: \.uid)
        case .bill: try Self.encode(archive.bills, key: \.uid)
        case .storeProduct: try Self.encode(archive.storeProducts, key: \.shopifyID)
        case .storeOrder: try Self.encode(archive.storeOrders, key: \.shopifyID)
        case .storeCheckout: try Self.encode(archive.storeCheckouts, key: \.shopifyID)
        case .dailyStat: try Self.encode(archive.dailyStats, key: { $0.date.backupKey })
        case .project: try Self.encode(archive.projects, key: \.uid)
        case .task: try Self.encode(archive.tasks, key: \.uid)
        case .goal: try Self.encode(archive.goals, key: \.uid)
        case .note: try Self.encode(archive.notes, key: \.uid)
        case .noteBlock: try Self.encode(archive.noteBlocks, key: \.uid)
        case .vehicle: try Self.encode(archive.vehicles, key: \.uid)
        case .fuelEntry: try Self.encode(archive.fuelEntries, key: \.uid)
        case .maintenance: try Self.encode(archive.maintenanceRecords, key: \.uid)
        case .carDeadline: try Self.encode(archive.carDeadlines, key: \.uid)
        case .document: try Self.encode(archive.documents, key: \.uid)
        case .jobApplication: try Self.encode(archive.jobApplications, key: \.uid)
        case .course: try Self.encode(archive.courses, key: \.uid)
        case .investment: try Self.encode(archive.investments, key: \.uid)
        case .wealthSnapshot: try Self.encode(archive.wealthSnapshots, key: { $0.day.backupKey })
        case .habit: try Self.encode(archive.habits, key: \.uid)
        case .habitCheck: try Self.encode(archive.habitChecks, key: \.uid)
        }
    }

    /// Lê um `payload` vindo do servidor e acrescenta-o à cópia.
    /// Devolve o mesmo registo em JSON canónico (para comparar com o local).
    @discardableResult
    func append(_ payload: Data, to archive: inout BackupArchive) throws -> Data {
        switch self {
        case .category: try Self.decode(payload, into: &archive.categories)
        case .account: try Self.decode(payload, into: &archive.accounts)
        case .transaction: try Self.decode(payload, into: &archive.transactions)
        case .bill: try Self.decode(payload, into: &archive.bills)
        case .storeProduct: try Self.decode(payload, into: &archive.storeProducts)
        case .storeOrder: try Self.decode(payload, into: &archive.storeOrders)
        case .storeCheckout: try Self.decode(payload, into: &archive.storeCheckouts)
        case .dailyStat: try Self.decode(payload, into: &archive.dailyStats)
        case .project: try Self.decode(payload, into: &archive.projects)
        case .task: try Self.decode(payload, into: &archive.tasks)
        case .goal: try Self.decode(payload, into: &archive.goals)
        case .note: try Self.decode(payload, into: &archive.notes)
        case .noteBlock: try Self.decode(payload, into: &archive.noteBlocks)
        case .vehicle: try Self.decode(payload, into: &archive.vehicles)
        case .fuelEntry: try Self.decode(payload, into: &archive.fuelEntries)
        case .maintenance: try Self.decode(payload, into: &archive.maintenanceRecords)
        case .carDeadline: try Self.decode(payload, into: &archive.carDeadlines)
        case .document: try Self.decode(payload, into: &archive.documents)
        case .jobApplication: try Self.decode(payload, into: &archive.jobApplications)
        case .course: try Self.decode(payload, into: &archive.courses)
        case .investment: try Self.decode(payload, into: &archive.investments)
        case .wealthSnapshot: try Self.decode(payload, into: &archive.wealthSnapshots)
        case .habit: try Self.decode(payload, into: &archive.habits)
        case .habitCheck: try Self.decode(payload, into: &archive.habitChecks)
        }
    }

    // MARK: - Apagar

    /// Apaga do SwiftData os modelos deste tipo com as chaves dadas (tombstones vindos do servidor).
    @MainActor
    @discardableResult
    func deleteModels(withKeys keys: Set<String>, in context: ModelContext) throws -> Int {
        guard !keys.isEmpty else { return 0 }
        return switch self {
        case .category: try Self.delete(Category.self, keys, { $0.uid }, context)
        case .account: try Self.delete(Account.self, keys, { $0.uid }, context)
        case .transaction: try Self.delete(FinanceTransaction.self, keys, { $0.uid }, context)
        case .bill: try Self.delete(Bill.self, keys, { $0.uid }, context)
        case .storeProduct: try Self.delete(StoreProduct.self, keys, { $0.shopifyID }, context)
        case .storeOrder: try Self.delete(StoreOrder.self, keys, { $0.shopifyID }, context)
        case .storeCheckout: try Self.delete(StoreCheckout.self, keys, { $0.shopifyID }, context)
        case .dailyStat: try Self.delete(DailyStat.self, keys, { $0.date.backupKey }, context)
        case .project: try Self.delete(Project.self, keys, { $0.uid }, context)
        case .task: try Self.delete(ProjectTask.self, keys, { $0.uid }, context)
        case .goal: try Self.delete(Goal.self, keys, { $0.uid }, context)
        case .note: try Self.delete(Note.self, keys, { $0.uid }, context)
        case .noteBlock: try Self.delete(NoteBlock.self, keys, { $0.uid }, context)
        case .vehicle: try Self.delete(Vehicle.self, keys, { $0.uid }, context)
        case .fuelEntry: try Self.delete(FuelEntry.self, keys, { $0.uid }, context)
        case .maintenance: try Self.delete(MaintenanceRecord.self, keys, { $0.uid }, context)
        case .carDeadline: try Self.delete(CarDeadline.self, keys, { $0.uid }, context)
        case .document: try Self.delete(PersonalDocument.self, keys, { $0.uid }, context)
        case .jobApplication: try Self.delete(JobApplication.self, keys, { $0.uid }, context)
        case .course: try Self.delete(Course.self, keys, { $0.uid }, context)
        case .investment: try Self.delete(Investment.self, keys, { $0.uid }, context)
        case .wealthSnapshot: try Self.delete(WealthSnapshot.self, keys, { $0.day.backupKey }, context)
        case .habit: try Self.delete(Habit.self, keys, { $0.uid }, context)
        case .habitCheck: try Self.delete(HabitCheck.self, keys, { $0.uid }, context)
        }
    }

    // MARK: - Auxiliares

    /// JSON canónico: chaves ordenadas e datas no formato nativo, como na cópia de segurança.
    static func canonicalJSON<R: Encodable>(_ record: R) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        return try encoder.encode(record)
    }

    private static func encode<R: Encodable>(_ records: [R], key: (R) -> String) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for record in records {
            result[key(record)] = try canonicalJSON(record)
        }
        return result
    }

    private static func decode<R: Codable>(_ payload: Data, into list: inout [R]) throws -> Data {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let record = try decoder.decode(R.self, from: payload)
        list.append(record)
        return try canonicalJSON(record)
    }

    @MainActor
    private static func delete<M: PersistentModel>(
        _: M.Type, _ keys: Set<String>, _ key: (M) -> String, _ context: ModelContext
    ) throws -> Int {
        let doomed = try context.fetch(FetchDescriptor<M>()).filter { keys.contains(key($0)) }
        doomed.forEach(context.delete)
        return doomed.count
    }
}
