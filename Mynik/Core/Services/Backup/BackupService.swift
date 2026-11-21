import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Exporta todos os dados para uma `BackupArchive` e importa-a de volta,
/// juntando ao que já existe sem criar duplicados.
///
/// Regras da importação:
/// - cada registo é reconhecido pelo seu `uid` (ou pelo id da Shopify / dia, nos dados da loja);
/// - categorias e contas criadas à parte em cada dispositivo (as iniciais, por exemplo)
///   são reconhecidas também pelo nome;
/// - o que é novo é acrescentado, o que existe é atualizado com a versão do ficheiro;
/// - nada é apagado.
@MainActor
enum BackupService {
    // MARK: - Exportar

    /// - Parameter includingDocumentPhotos: `false` deixa de fora as fotos dos documentos
    ///   (o sync com o Supabase nunca as envia).
    static func makeArchive(
        from context: ModelContext,
        now: Date = .now,
        includingDocumentPhotos: Bool = true
    ) throws -> BackupArchive {
        var archive = BackupArchive()
        archive.exportedAt = now
        archive.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        archive.device = deviceName

        func all<M: PersistentModel>(_: M.Type) throws -> [M] {
            try context.fetch(FetchDescriptor<M>())
        }

        archive.categories = try all(Category.self).map(CategoryRecord.init).sorted { $0.uid < $1.uid }
        archive.accounts = try all(Account.self).map(AccountRecord.init).sorted { $0.uid < $1.uid }
        archive.transactions = try all(FinanceTransaction.self).map(TransactionRecord.init).sorted { $0.uid < $1.uid }
        archive.bills = try all(Bill.self).map(BillRecord.init).sorted { $0.uid < $1.uid }
        archive.storeProducts = try all(StoreProduct.self).map(StoreProductRecord.init).sorted { $0.shopifyID < $1.shopifyID }
        archive.storeOrders = try all(StoreOrder.self).map(StoreOrderRecord.init).sorted { $0.shopifyID < $1.shopifyID }
        archive.storeCheckouts = try all(StoreCheckout.self).map(StoreCheckoutRecord.init).sorted { $0.shopifyID < $1.shopifyID }
        archive.dailyStats = try all(DailyStat.self).map(DailyStatRecord.init).sorted { $0.date < $1.date }
        archive.projects = try all(Project.self).map(ProjectRecord.init).sorted { $0.uid < $1.uid }
        archive.tasks = try all(ProjectTask.self).map(ProjectTaskRecord.init).sorted { $0.uid < $1.uid }
        archive.goals = try all(Goal.self).map(GoalRecord.init).sorted { $0.uid < $1.uid }
        archive.notes = try all(Note.self).map(NoteRecord.init).sorted { $0.uid < $1.uid }
        archive.noteBlocks = try all(NoteBlock.self).map(NoteBlockRecord.init).sorted { $0.uid < $1.uid }
        archive.vehicles = try all(Vehicle.self).map(VehicleRecord.init).sorted { $0.uid < $1.uid }
        archive.fuelEntries = try all(FuelEntry.self).map(FuelEntryRecord.init).sorted { $0.uid < $1.uid }
        archive.maintenanceRecords = try all(MaintenanceRecord.self).map(MaintenanceRecordRecord.init).sorted { $0.uid < $1.uid }
        archive.carDeadlines = try all(CarDeadline.self).map(CarDeadlineRecord.init).sorted { $0.uid < $1.uid }
        archive.documents = try all(PersonalDocument.self).map(PersonalDocumentRecord.init).sorted { $0.uid < $1.uid }
        if includingDocumentPhotos {
            archive.documentPhotos = try all(DocumentPhoto.self).map(DocumentPhotoRecord.init).sorted { $0.uid < $1.uid }
        }
        archive.jobApplications = try all(JobApplication.self).map(JobApplicationRecord.init).sorted { $0.uid < $1.uid }
        archive.courses = try all(Course.self).map(CourseRecord.init).sorted { $0.uid < $1.uid }
        archive.investments = try all(Investment.self).map(InvestmentRecord.init).sorted { $0.uid < $1.uid }
        archive.wealthSnapshots = try all(WealthSnapshot.self).map(WealthSnapshotRecord.init).sorted { $0.day < $1.day }
        archive.habits = try all(Habit.self).map(HabitRecord.init).sorted { $0.uid < $1.uid }
        archive.habitChecks = try all(HabitCheck.self).map(HabitCheckRecord.init).sorted { $0.uid < $1.uid }
        return archive
    }

    /// `true` se a cópia vai incluir números ou fotos de documentos (pede Face ID antes).
    static func containsDocuments(in context: ModelContext) -> Bool {
        ((try? context.fetchCount(FetchDescriptor<PersonalDocument>())) ?? 0) > 0
    }

    private static var deviceName: String {
        #if os(macOS)
        Host.current().localizedName ?? "Mac"
        #else
        UIDevice.current.model
        #endif
    }

    // MARK: - Importar

    @discardableResult
    static func importArchive(_ archive: BackupArchive, into context: ModelContext) throws -> BackupImportSummary {
        var merger = Merger(context: context)

        let categories = try merger.merge(
            archive.categories, key: \.uid, modelKey: { $0.uid },
            fallbackKey: { "\($0.kindRaw)|\($0.name.normalizedKey)" },
            modelFallbackKey: { "\($0.kindRaw)|\($0.name.normalizedKey)" },
            make: { Category(name: "", symbolName: "tag", color: .gray, kind: .expense) },
            snapshot: CategoryRecord.init, apply: { $0.apply(to: $1) }
        )
        let accounts = try merger.merge(
            archive.accounts, key: \.uid, modelKey: { $0.uid },
            fallbackKey: { $0.name.normalizedKey }, modelFallbackKey: { $0.name.normalizedKey },
            make: { Account(name: "") },
            snapshot: AccountRecord.init, apply: { $0.apply(to: $1) }
        )
        let transactions = try merger.merge(
            archive.transactions, key: \.uid, modelKey: { $0.uid },
            make: { FinanceTransaction(title: "", amount: 0, kind: .expense) },
            snapshot: TransactionRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.transactions {
            guard let model = transactions[record.uid] else { continue }
            model.category = record.categoryUID.flatMap { categories[$0] }
            model.account = record.accountUID.flatMap { accounts[$0] }
        }
        let bills = try merger.merge(
            archive.bills, key: \.uid, modelKey: { $0.uid },
            make: { Bill(title: "", amount: 0, dueDate: .now) },
            snapshot: BillRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.bills {
            guard let model = bills[record.uid] else { continue }
            model.category = record.categoryUID.flatMap { categories[$0] }
            model.account = record.accountUID.flatMap { accounts[$0] }
        }

        try merger.merge(
            archive.storeProducts, key: \.shopifyID, modelKey: { $0.shopifyID },
            make: { StoreProduct(shopifyID: "", title: "") },
            snapshot: StoreProductRecord.init, apply: { $0.apply(to: $1) }
        )
        try merger.merge(
            archive.storeOrders, key: \.shopifyID, modelKey: { $0.shopifyID },
            make: { StoreOrder(shopifyID: "", name: "", createdAt: .now) },
            snapshot: StoreOrderRecord.init, apply: { $0.apply(to: $1) }
        )
        try merger.merge(
            archive.storeCheckouts, key: \.shopifyID, modelKey: { $0.shopifyID },
            make: { StoreCheckout(shopifyID: "", name: "", createdAt: .now) },
            snapshot: StoreCheckoutRecord.init, apply: { $0.apply(to: $1) }
        )
        try merger.merge(
            archive.dailyStats, key: { $0.date.backupKey }, modelKey: { $0.date.backupKey },
            make: { DailyStat(date: .now) },
            snapshot: DailyStatRecord.init, apply: { $0.apply(to: $1) }
        )

        let projects = try merger.merge(
            archive.projects, key: \.uid, modelKey: { $0.uid },
            make: { Project(name: "") },
            snapshot: ProjectRecord.init, apply: { $0.apply(to: $1) }
        )
        let tasks = try merger.merge(
            archive.tasks, key: \.uid, modelKey: { $0.uid },
            make: { ProjectTask(title: "") },
            snapshot: ProjectTaskRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.tasks {
            tasks[record.uid]?.project = record.projectUID.flatMap { projects[$0] }
        }
        let goals = try merger.merge(
            archive.goals, key: \.uid, modelKey: { $0.uid },
            make: { Goal(title: "", targetAmount: 0) },
            snapshot: GoalRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.goals {
            guard let model = goals[record.uid] else { continue }
            model.account = record.accountUID.flatMap { accounts[$0] }
            model.category = record.categoryUID.flatMap { categories[$0] }
        }

        let notes = try merger.merge(
            archive.notes, key: \.uid, modelKey: { $0.uid },
            make: { Note() },
            snapshot: NoteRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.notes {
            guard let model = notes[record.uid] else { continue }
            model.parent = record.parentUID.flatMap { notes[$0] }
            model.linkedProjects = record.linkedProjectUIDs.compactMap { projects[$0] }
            model.linkedTransactions = record.linkedTransactionUIDs.compactMap { transactions[$0] }
            model.linkedNotes = record.linkedNoteUIDs.compactMap { notes[$0] }
        }
        let blocks = try merger.merge(
            archive.noteBlocks, key: \.uid, modelKey: { $0.uid },
            make: { NoteBlock(kind: .text) },
            snapshot: NoteBlockRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.noteBlocks {
            blocks[record.uid]?.note = record.noteUID.flatMap { notes[$0] }
        }

        let vehicles = try merger.merge(
            archive.vehicles, key: \.uid, modelKey: { $0.uid },
            make: { Vehicle(name: "") },
            snapshot: VehicleRecord.init, apply: { $0.apply(to: $1) }
        )
        let fuel = try merger.merge(
            archive.fuelEntries, key: \.uid, modelKey: { $0.uid },
            make: { FuelEntry(date: .now, odometer: 0, quantity: 0, totalCost: 0) },
            snapshot: FuelEntryRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.fuelEntries {
            fuel[record.uid]?.vehicle = record.vehicleUID.flatMap { vehicles[$0] }
        }
        let maintenance = try merger.merge(
            archive.maintenanceRecords, key: \.uid, modelKey: { $0.uid },
            make: { MaintenanceRecord(kind: .service, date: .now) },
            snapshot: MaintenanceRecordRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.maintenanceRecords {
            maintenance[record.uid]?.vehicle = record.vehicleUID.flatMap { vehicles[$0] }
        }
        let deadlines = try merger.merge(
            archive.carDeadlines, key: \.uid, modelKey: { $0.uid },
            make: { CarDeadline(kind: .inspection, dueDate: .now) },
            snapshot: CarDeadlineRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.carDeadlines {
            deadlines[record.uid]?.vehicle = record.vehicleUID.flatMap { vehicles[$0] }
        }

        let documents = try merger.merge(
            archive.documents, key: \.uid, modelKey: { $0.uid },
            make: { PersonalDocument(kind: .idCard) },
            snapshot: PersonalDocumentRecord.init, apply: { $0.apply(to: $1) }
        )
        let photos = try merger.merge(
            archive.documentPhotos, key: \.uid, modelKey: { $0.uid },
            make: { DocumentPhoto(imageData: Data()) },
            snapshot: DocumentPhotoRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.documentPhotos {
            photos[record.uid]?.document = record.documentUID.flatMap { documents[$0] }
        }

        try merger.merge(
            archive.jobApplications, key: \.uid, modelKey: { $0.uid },
            make: { JobApplication(company: "", role: "") },
            snapshot: JobApplicationRecord.init, apply: { $0.apply(to: $1) }
        )
        try merger.merge(
            archive.courses, key: \.uid, modelKey: { $0.uid },
            make: { Course(title: "") },
            snapshot: CourseRecord.init, apply: { $0.apply(to: $1) }
        )
        try merger.merge(
            archive.investments, key: \.uid, modelKey: { $0.uid },
            make: { Investment(name: "", kind: .etf) },
            snapshot: InvestmentRecord.init, apply: { $0.apply(to: $1) }
        )
        try merger.merge(
            archive.wealthSnapshots, key: { $0.day.backupKey }, modelKey: { $0.day.backupKey },
            make: { WealthSnapshot(day: .now) },
            snapshot: WealthSnapshotRecord.init, apply: { $0.apply(to: $1) }
        )

        let habits = try merger.merge(
            archive.habits, key: \.uid, modelKey: { $0.uid },
            make: { Habit(name: "") },
            snapshot: HabitRecord.init, apply: { $0.apply(to: $1) }
        )
        let checks = try merger.merge(
            archive.habitChecks, key: \.uid, modelKey: { $0.uid },
            make: { HabitCheck(day: .now) },
            snapshot: HabitCheckRecord.init, apply: { $0.apply(to: $1) }
        )
        for record in archive.habitChecks {
            checks[record.uid]?.habit = record.habitUID.flatMap { habits[$0] }
        }

        try context.save()
        return merger.summary
    }
}

/// Junta registos a modelos de um tipo, contando o que mudou.
@MainActor
private struct Merger {
    let context: ModelContext
    var summary = BackupImportSummary()

    /// Devolve todos os modelos do tipo (os que já existiam e os novos), indexados pela chave.
    @discardableResult
    mutating func merge<M: PersistentModel, R: Equatable>(
        _ records: [R],
        key: (R) -> String,
        modelKey: (M) -> String,
        fallbackKey: ((R) -> String)? = nil,
        modelFallbackKey: ((M) -> String)? = nil,
        make: () -> M,
        snapshot: (M) -> R,
        apply: (R, M) -> Void
    ) throws -> [String: M] {
        let existing = try context.fetch(FetchDescriptor<M>())
        var index = Dictionary(existing.map { (modelKey($0), $0) }, uniquingKeysWith: { first, _ in first })
        var fallbackIndex: [String: M] = [:]
        if let modelFallbackKey {
            fallbackIndex = Dictionary(existing.map { (modelFallbackKey($0), $0) }, uniquingKeysWith: { first, _ in first })
        }

        for record in records {
            let recordKey = key(record)
            if let model = index[recordKey] ?? fallbackKey.flatMap({ fallbackIndex[$0(record)] }) {
                if snapshot(model) == record {
                    summary.unchanged += 1
                } else {
                    apply(record, model)
                    summary.updated += 1
                }
                index[recordKey] = model
            } else {
                let model = make()
                context.insert(model)
                apply(record, model)
                index[recordKey] = model
                summary.inserted += 1
            }
        }
        return index
    }
}

private extension String {
    /// Nome sem diferenças de maiúsculas, acentos ou espaços nas pontas.
    nonisolated var normalizedKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

extension Date {
    /// Chave estável de um registo identificado por data (resumos diários, património).
    nonisolated var backupKey: String { String(timeIntervalSince1970) }
}
