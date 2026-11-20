import Foundation

/// Cópia de segurança completa do Mynik: todos os dados, num só ficheiro JSON.
///
/// Substitui o sync por iCloud (que exige o Apple Developer Program): exporta-se
/// num dispositivo e importa-se no outro por AirDrop, iCloud Drive ou Ficheiros.
nonisolated struct BackupArchive: Codable, Equatable, Sendable {
    /// Versão do formato do ficheiro (não da app).
    static let currentFormat = 1

    var format = BackupArchive.currentFormat
    var exportedAt = Date.now
    var appVersion = ""
    var device = ""

    var categories: [CategoryRecord] = []
    var accounts: [AccountRecord] = []
    var transactions: [TransactionRecord] = []
    var bills: [BillRecord] = []
    var storeProducts: [StoreProductRecord] = []
    var storeOrders: [StoreOrderRecord] = []
    var storeCheckouts: [StoreCheckoutRecord] = []
    var dailyStats: [DailyStatRecord] = []
    var projects: [ProjectRecord] = []
    var tasks: [ProjectTaskRecord] = []
    var goals: [GoalRecord] = []
    var notes: [NoteRecord] = []
    var noteBlocks: [NoteBlockRecord] = []
    var vehicles: [VehicleRecord] = []
    var fuelEntries: [FuelEntryRecord] = []
    var maintenanceRecords: [MaintenanceRecordRecord] = []
    var carDeadlines: [CarDeadlineRecord] = []
    var documents: [PersonalDocumentRecord] = []
    var documentPhotos: [DocumentPhotoRecord] = []
    var jobApplications: [JobApplicationRecord] = []
    var courses: [CourseRecord] = []
    var investments: [InvestmentRecord] = []
    var wealthSnapshots: [WealthSnapshotRecord] = []
    var habits: [HabitRecord] = []
    var habitChecks: [HabitCheckRecord] = []

    init() {}

    /// Número total de registos no ficheiro.
    var recordCount: Int {
        categories.count + accounts.count + transactions.count + bills.count
            + storeProducts.count + storeOrders.count + storeCheckouts.count + dailyStats.count
            + projects.count + tasks.count + goals.count + notes.count + noteBlocks.count
            + vehicles.count + fuelEntries.count + maintenanceRecords.count + carDeadlines.count
            + documents.count + documentPhotos.count + jobApplications.count + courses.count
            + investments.count + wealthSnapshots.count + habits.count + habitChecks.count
    }

    // MARK: - JSON

    static func decode(_ data: Data) throws -> BackupArchive {
        let archive: BackupArchive
        do {
            archive = try decoder.decode(BackupArchive.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
        guard archive.format <= currentFormat else { throw BackupError.newerFormat }
        return archive
    }

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    /// Nome sugerido para o ficheiro, por exemplo `Mynik-2026-11-20.json`.
    var suggestedFileName: String {
        "Mynik-\(exportedAt.formatted(.iso8601.year().month().day())).json"
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        // Datas no formato nativo (segundos desde 2001): ida e volta sem perdas.
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    // Listas em falta (ficheiros antigos ou editados à mão) contam como vazias.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(Int.self, forKey: .format)
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .now
        appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion) ?? ""
        device = try c.decodeIfPresent(String.self, forKey: .device) ?? ""
        categories = try c.decodeIfPresent([CategoryRecord].self, forKey: .categories) ?? []
        accounts = try c.decodeIfPresent([AccountRecord].self, forKey: .accounts) ?? []
        transactions = try c.decodeIfPresent([TransactionRecord].self, forKey: .transactions) ?? []
        bills = try c.decodeIfPresent([BillRecord].self, forKey: .bills) ?? []
        storeProducts = try c.decodeIfPresent([StoreProductRecord].self, forKey: .storeProducts) ?? []
        storeOrders = try c.decodeIfPresent([StoreOrderRecord].self, forKey: .storeOrders) ?? []
        storeCheckouts = try c.decodeIfPresent([StoreCheckoutRecord].self, forKey: .storeCheckouts) ?? []
        dailyStats = try c.decodeIfPresent([DailyStatRecord].self, forKey: .dailyStats) ?? []
        projects = try c.decodeIfPresent([ProjectRecord].self, forKey: .projects) ?? []
        tasks = try c.decodeIfPresent([ProjectTaskRecord].self, forKey: .tasks) ?? []
        goals = try c.decodeIfPresent([GoalRecord].self, forKey: .goals) ?? []
        notes = try c.decodeIfPresent([NoteRecord].self, forKey: .notes) ?? []
        noteBlocks = try c.decodeIfPresent([NoteBlockRecord].self, forKey: .noteBlocks) ?? []
        vehicles = try c.decodeIfPresent([VehicleRecord].self, forKey: .vehicles) ?? []
        fuelEntries = try c.decodeIfPresent([FuelEntryRecord].self, forKey: .fuelEntries) ?? []
        maintenanceRecords = try c.decodeIfPresent([MaintenanceRecordRecord].self, forKey: .maintenanceRecords) ?? []
        carDeadlines = try c.decodeIfPresent([CarDeadlineRecord].self, forKey: .carDeadlines) ?? []
        documents = try c.decodeIfPresent([PersonalDocumentRecord].self, forKey: .documents) ?? []
        documentPhotos = try c.decodeIfPresent([DocumentPhotoRecord].self, forKey: .documentPhotos) ?? []
        jobApplications = try c.decodeIfPresent([JobApplicationRecord].self, forKey: .jobApplications) ?? []
        courses = try c.decodeIfPresent([CourseRecord].self, forKey: .courses) ?? []
        investments = try c.decodeIfPresent([InvestmentRecord].self, forKey: .investments) ?? []
        wealthSnapshots = try c.decodeIfPresent([WealthSnapshotRecord].self, forKey: .wealthSnapshots) ?? []
        // Cópias anteriores à v0.7 não têm hábitos.
        habits = try c.decodeIfPresent([HabitRecord].self, forKey: .habits) ?? []
        habitChecks = try c.decodeIfPresent([HabitCheckRecord].self, forKey: .habitChecks) ?? []
    }
}

nonisolated enum BackupError: LocalizedError, Equatable {
    case unreadable
    case newerFormat

    var errorDescription: String? {
        switch self {
        case .unreadable: "O ficheiro não é uma cópia do Mynik válida."
        case .newerFormat: "Esta cópia foi feita por uma versão mais recente do Mynik. Atualiza a app e tenta de novo."
        }
    }
}

/// Resultado de uma importação.
nonisolated struct BackupImportSummary: Equatable, Sendable {
    var inserted = 0
    var updated = 0
    var unchanged = 0

    var description: String {
        if inserted == 0 && updated == 0 { return "Já estava tudo igual: nada a importar." }
        return "Importado: \(inserted) novos · \(updated) atualizados · \(unchanged) sem alterações."
    }
}
