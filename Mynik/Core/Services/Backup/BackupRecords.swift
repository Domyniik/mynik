import Foundation

// Gerado a partir dos modelos SwiftData: um registo por modelo, com as
// relações guardadas como identificadores (`uid`). Ao acrescentar uma
// propriedade a um modelo, acrescenta-a também aqui como opcional, para que
// as cópias feitas por versões anteriores continuem a abrir.

/// Cópia de `Category`.
nonisolated struct CategoryRecord: Codable, Equatable, Sendable {
    var uid: String
    var name: String
    var symbolName: String
    var colorName: String
    var kindRaw: String
    var sortOrder: Int
    var monthlyBudget: Decimal
}

extension CategoryRecord {
    @MainActor init(_ model: Category) {
        uid = model.uid
        name = model.name
        symbolName = model.symbolName
        colorName = model.colorName
        kindRaw = model.kindRaw
        sortOrder = model.sortOrder
        monthlyBudget = model.monthlyBudget
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Category) {
        model.uid = uid
        model.name = name
        model.symbolName = symbolName
        model.colorName = colorName
        model.kindRaw = kindRaw
        model.sortOrder = sortOrder
        model.monthlyBudget = monthlyBudget
    }
}

/// Cópia de `Account`.
nonisolated struct AccountRecord: Codable, Equatable, Sendable {
    var uid: String
    var name: String
    var typeRaw: String
    var currencyCode: String
    var initialBalance: Decimal
    var isArchived: Bool
    var createdAt: Date
}

extension AccountRecord {
    @MainActor init(_ model: Account) {
        uid = model.uid
        name = model.name
        typeRaw = model.typeRaw
        currencyCode = model.currencyCode
        initialBalance = model.initialBalance
        isArchived = model.isArchived
        createdAt = model.createdAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Account) {
        model.uid = uid
        model.name = name
        model.typeRaw = typeRaw
        model.currencyCode = currencyCode
        model.initialBalance = initialBalance
        model.isArchived = isArchived
        model.createdAt = createdAt
    }
}

/// Cópia de `FinanceTransaction`.
nonisolated struct TransactionRecord: Codable, Equatable, Sendable {
    var uid: String
    var title: String
    var amount: Decimal
    var kindRaw: String
    var currencyCode: String
    var date: Date
    var notes: String
    var createdAt: Date
    var externalID: String
    var categoryUID: String?
    var accountUID: String?
}

extension TransactionRecord {
    @MainActor init(_ model: FinanceTransaction) {
        uid = model.uid
        title = model.title
        amount = model.amount
        kindRaw = model.kindRaw
        currencyCode = model.currencyCode
        date = model.date
        notes = model.notes
        createdAt = model.createdAt
        externalID = model.externalID
        categoryUID = model.category?.uid
        accountUID = model.account?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: FinanceTransaction) {
        model.uid = uid
        model.title = title
        model.amount = amount
        model.kindRaw = kindRaw
        model.currencyCode = currencyCode
        model.date = date
        model.notes = notes
        model.createdAt = createdAt
        model.externalID = externalID
    }
}

/// Cópia de `Bill`.
nonisolated struct BillRecord: Codable, Equatable, Sendable {
    var uid: String
    var title: String
    var amount: Decimal
    var currencyCode: String
    var dueDate: Date
    var isPaid: Bool
    var paidAt: Date?
    var recurrenceRaw: String
    var notes: String
    var isSubscription: Bool
    var createdAt: Date
    var categoryUID: String?
    var accountUID: String?
}

extension BillRecord {
    @MainActor init(_ model: Bill) {
        uid = model.uid
        title = model.title
        amount = model.amount
        currencyCode = model.currencyCode
        dueDate = model.dueDate
        isPaid = model.isPaid
        paidAt = model.paidAt
        recurrenceRaw = model.recurrenceRaw
        notes = model.notes
        isSubscription = model.isSubscription
        createdAt = model.createdAt
        categoryUID = model.category?.uid
        accountUID = model.account?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Bill) {
        model.uid = uid
        model.title = title
        model.amount = amount
        model.currencyCode = currencyCode
        model.dueDate = dueDate
        model.isPaid = isPaid
        model.paidAt = paidAt
        model.recurrenceRaw = recurrenceRaw
        model.notes = notes
        model.isSubscription = isSubscription
        model.createdAt = createdAt
    }
}

/// Cópia de `StoreProduct`.
nonisolated struct StoreProductRecord: Codable, Equatable, Sendable {
    var shopifyID: String
    var title: String
    var handle: String
    var statusRaw: String
    var imageURLString: String
    var price: Decimal
    var unitCost: Decimal
    var unitCostIsManual: Bool
    var inventory: Int
    var tracksInventory: Bool
    var createdAt: Date
    var adSpend30d: Decimal
    var decisionRaw: String
    var decidedAt: Date?
    var decisionNote: String
    var syncedAt: Date
}

extension StoreProductRecord {
    @MainActor init(_ model: StoreProduct) {
        shopifyID = model.shopifyID
        title = model.title
        handle = model.handle
        statusRaw = model.statusRaw
        imageURLString = model.imageURLString
        price = model.price
        unitCost = model.unitCost
        unitCostIsManual = model.unitCostIsManual
        inventory = model.inventory
        tracksInventory = model.tracksInventory
        createdAt = model.createdAt
        adSpend30d = model.adSpend30d
        decisionRaw = model.decisionRaw
        decidedAt = model.decidedAt
        decisionNote = model.decisionNote
        syncedAt = model.syncedAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: StoreProduct) {
        model.shopifyID = shopifyID
        model.title = title
        model.handle = handle
        model.statusRaw = statusRaw
        model.imageURLString = imageURLString
        model.price = price
        model.unitCost = unitCost
        model.unitCostIsManual = unitCostIsManual
        model.inventory = inventory
        model.tracksInventory = tracksInventory
        model.createdAt = createdAt
        model.adSpend30d = adSpend30d
        model.decisionRaw = decisionRaw
        model.decidedAt = decidedAt
        model.decisionNote = decisionNote
        model.syncedAt = syncedAt
    }
}

/// Cópia de `StoreOrder`.
nonisolated struct StoreOrderRecord: Codable, Equatable, Sendable {
    var shopifyID: String
    var name: String
    var createdAt: Date
    var cancelledAt: Date?
    var subtotal: Decimal
    var shipping: Decimal
    var tax: Decimal
    var total: Decimal
    var refunded: Decimal
    var currencyCode: String
    var financialStatusRaw: String
    var fulfillmentStatusRaw: String
    var lines: [StoreOrderLine]
    var syncedAt: Date
}

extension StoreOrderRecord {
    @MainActor init(_ model: StoreOrder) {
        shopifyID = model.shopifyID
        name = model.name
        createdAt = model.createdAt
        cancelledAt = model.cancelledAt
        subtotal = model.subtotal
        shipping = model.shipping
        tax = model.tax
        total = model.total
        refunded = model.refunded
        currencyCode = model.currencyCode
        financialStatusRaw = model.financialStatusRaw
        fulfillmentStatusRaw = model.fulfillmentStatusRaw
        lines = model.lines
        syncedAt = model.syncedAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: StoreOrder) {
        model.shopifyID = shopifyID
        model.name = name
        model.createdAt = createdAt
        model.cancelledAt = cancelledAt
        model.subtotal = subtotal
        model.shipping = shipping
        model.tax = tax
        model.total = total
        model.refunded = refunded
        model.currencyCode = currencyCode
        model.financialStatusRaw = financialStatusRaw
        model.fulfillmentStatusRaw = fulfillmentStatusRaw
        model.lines = lines
        model.syncedAt = syncedAt
    }
}

/// Cópia de `StoreCheckout`.
nonisolated struct StoreCheckoutRecord: Codable, Equatable, Sendable {
    var shopifyID: String
    var name: String
    var createdAt: Date
    var total: Decimal
    var recoveryURLString: String
    var lines: [StoreCheckoutLine]
    var syncedAt: Date
}

extension StoreCheckoutRecord {
    @MainActor init(_ model: StoreCheckout) {
        shopifyID = model.shopifyID
        name = model.name
        createdAt = model.createdAt
        total = model.total
        recoveryURLString = model.recoveryURLString
        lines = model.lines
        syncedAt = model.syncedAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: StoreCheckout) {
        model.shopifyID = shopifyID
        model.name = name
        model.createdAt = createdAt
        model.total = total
        model.recoveryURLString = recoveryURLString
        model.lines = lines
        model.syncedAt = syncedAt
    }
}

/// Cópia de `DailyStat`.
nonisolated struct DailyStatRecord: Codable, Equatable, Sendable {
    var date: Date
    var sales: Decimal
    var netRevenue: Decimal
    var orders: Int
    var units: Int
    var refunds: Decimal
    var sessions: Int
    var cartSessions: Int
    var checkoutSessions: Int
    var completedSessions: Int
    var hasTraffic: Bool
}

extension DailyStatRecord {
    @MainActor init(_ model: DailyStat) {
        date = model.date
        sales = model.sales
        netRevenue = model.netRevenue
        orders = model.orders
        units = model.units
        refunds = model.refunds
        sessions = model.sessions
        cartSessions = model.cartSessions
        checkoutSessions = model.checkoutSessions
        completedSessions = model.completedSessions
        hasTraffic = model.hasTraffic
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: DailyStat) {
        model.date = date
        model.sales = sales
        model.netRevenue = netRevenue
        model.orders = orders
        model.units = units
        model.refunds = refunds
        model.sessions = sessions
        model.cartSessions = cartSessions
        model.checkoutSessions = checkoutSessions
        model.completedSessions = completedSessions
        model.hasTraffic = hasTraffic
    }
}

/// Cópia de `Project`.
nonisolated struct ProjectRecord: Codable, Equatable, Sendable {
    var uid: String
    var name: String
    var details: String
    var symbolName: String
    var colorName: String
    var statusRaw: String
    var dueDate: Date?
    var createdAt: Date
}

extension ProjectRecord {
    @MainActor init(_ model: Project) {
        uid = model.uid
        name = model.name
        details = model.details
        symbolName = model.symbolName
        colorName = model.colorName
        statusRaw = model.statusRaw
        dueDate = model.dueDate
        createdAt = model.createdAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Project) {
        model.uid = uid
        model.name = name
        model.details = details
        model.symbolName = symbolName
        model.colorName = colorName
        model.statusRaw = statusRaw
        model.dueDate = dueDate
        model.createdAt = createdAt
    }
}

/// Cópia de `ProjectTask`.
nonisolated struct ProjectTaskRecord: Codable, Equatable, Sendable {
    var uid: String
    var title: String
    var notes: String
    var statusRaw: String
    var priorityRaw: Int
    var dueDate: Date?
    var completedAt: Date?
    var createdAt: Date
    var projectUID: String?
}

extension ProjectTaskRecord {
    @MainActor init(_ model: ProjectTask) {
        uid = model.uid
        title = model.title
        notes = model.notes
        statusRaw = model.statusRaw
        priorityRaw = model.priorityRaw
        dueDate = model.dueDate
        completedAt = model.completedAt
        createdAt = model.createdAt
        projectUID = model.project?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: ProjectTask) {
        model.uid = uid
        model.title = title
        model.notes = notes
        model.statusRaw = statusRaw
        model.priorityRaw = priorityRaw
        model.dueDate = dueDate
        model.completedAt = completedAt
        model.createdAt = createdAt
    }
}

/// Cópia de `Goal`.
nonisolated struct GoalRecord: Codable, Equatable, Sendable {
    var uid: String
    var title: String
    var targetAmount: Decimal
    var currencyCode: String
    var deadline: Date?
    var symbolName: String
    var colorName: String
    var sourceRaw: String
    var manualAmount: Decimal
    var startDate: Date
    var isArchived: Bool
    var createdAt: Date
    var accountUID: String?
    var categoryUID: String?
}

extension GoalRecord {
    @MainActor init(_ model: Goal) {
        uid = model.uid
        title = model.title
        targetAmount = model.targetAmount
        currencyCode = model.currencyCode
        deadline = model.deadline
        symbolName = model.symbolName
        colorName = model.colorName
        sourceRaw = model.sourceRaw
        manualAmount = model.manualAmount
        startDate = model.startDate
        isArchived = model.isArchived
        createdAt = model.createdAt
        accountUID = model.account?.uid
        categoryUID = model.category?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Goal) {
        model.uid = uid
        model.title = title
        model.targetAmount = targetAmount
        model.currencyCode = currencyCode
        model.deadline = deadline
        model.symbolName = symbolName
        model.colorName = colorName
        model.sourceRaw = sourceRaw
        model.manualAmount = manualAmount
        model.startDate = startDate
        model.isArchived = isArchived
        model.createdAt = createdAt
    }
}

/// Cópia de `Note`.
nonisolated struct NoteRecord: Codable, Equatable, Sendable {
    var uid: String
    var title: String
    var icon: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var parentUID: String?
    var linkedProjectUIDs: [String] = []
    var linkedTransactionUIDs: [String] = []
    var linkedNoteUIDs: [String] = []
}

extension NoteRecord {
    @MainActor init(_ model: Note) {
        uid = model.uid
        title = model.title
        icon = model.icon
        createdAt = model.createdAt
        updatedAt = model.updatedAt
        sortOrder = model.sortOrder
        parentUID = model.parent?.uid
        linkedProjectUIDs = (model.linkedProjects ?? []).map(\.uid).sorted()
        linkedTransactionUIDs = (model.linkedTransactions ?? []).map(\.uid).sorted()
        linkedNoteUIDs = (model.linkedNotes ?? []).map(\.uid).sorted()
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Note) {
        model.uid = uid
        model.title = title
        model.icon = icon
        model.createdAt = createdAt
        model.updatedAt = updatedAt
        model.sortOrder = sortOrder
    }
}

/// Cópia de `NoteBlock`.
nonisolated struct NoteBlockRecord: Codable, Equatable, Sendable {
    var uid: String
    var kindRaw: String
    var text: String
    var isChecked: Bool
    var imageData: Data?
    var sortOrder: Int
    var createdAt: Date
    var noteUID: String?
}

extension NoteBlockRecord {
    @MainActor init(_ model: NoteBlock) {
        uid = model.uid
        kindRaw = model.kindRaw
        text = model.text
        isChecked = model.isChecked
        imageData = model.imageData
        sortOrder = model.sortOrder
        createdAt = model.createdAt
        noteUID = model.note?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: NoteBlock) {
        model.uid = uid
        model.kindRaw = kindRaw
        model.text = text
        model.isChecked = isChecked
        model.imageData = imageData
        model.sortOrder = sortOrder
        model.createdAt = createdAt
    }
}

/// Cópia de `Vehicle`.
nonisolated struct VehicleRecord: Codable, Equatable, Sendable {
    var uid: String
    var name: String
    var plate: String
    var fuelTypeRaw: String
    var initialOdometer: Int
    var notes: String
    var createdAt: Date
}

extension VehicleRecord {
    @MainActor init(_ model: Vehicle) {
        uid = model.uid
        name = model.name
        plate = model.plate
        fuelTypeRaw = model.fuelTypeRaw
        initialOdometer = model.initialOdometer
        notes = model.notes
        createdAt = model.createdAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Vehicle) {
        model.uid = uid
        model.name = name
        model.plate = plate
        model.fuelTypeRaw = fuelTypeRaw
        model.initialOdometer = initialOdometer
        model.notes = notes
        model.createdAt = createdAt
    }
}

/// Cópia de `FuelEntry`.
nonisolated struct FuelEntryRecord: Codable, Equatable, Sendable {
    var uid: String
    var date: Date
    var odometer: Int
    var quantity: Double
    var totalCost: Decimal
    var currencyCode: String
    var isFullTank: Bool
    var station: String
    var notes: String
    var transactionID: String
    var createdAt: Date
    var vehicleUID: String?
}

extension FuelEntryRecord {
    @MainActor init(_ model: FuelEntry) {
        uid = model.uid
        date = model.date
        odometer = model.odometer
        quantity = model.quantity
        totalCost = model.totalCost
        currencyCode = model.currencyCode
        isFullTank = model.isFullTank
        station = model.station
        notes = model.notes
        transactionID = model.transactionID
        createdAt = model.createdAt
        vehicleUID = model.vehicle?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: FuelEntry) {
        model.uid = uid
        model.date = date
        model.odometer = odometer
        model.quantity = quantity
        model.totalCost = totalCost
        model.currencyCode = currencyCode
        model.isFullTank = isFullTank
        model.station = station
        model.notes = notes
        model.transactionID = transactionID
        model.createdAt = createdAt
    }
}

/// Cópia de `MaintenanceRecord`.
nonisolated struct MaintenanceRecordRecord: Codable, Equatable, Sendable {
    var uid: String
    var kindRaw: String
    var title: String
    var date: Date
    var odometer: Int
    var cost: Decimal
    var currencyCode: String
    var workshop: String
    var notes: String
    var nextDueDate: Date?
    var nextDueOdometer: Int
    var transactionID: String
    var createdAt: Date
    var vehicleUID: String?
}

extension MaintenanceRecordRecord {
    @MainActor init(_ model: MaintenanceRecord) {
        uid = model.uid
        kindRaw = model.kindRaw
        title = model.title
        date = model.date
        odometer = model.odometer
        cost = model.cost
        currencyCode = model.currencyCode
        workshop = model.workshop
        notes = model.notes
        nextDueDate = model.nextDueDate
        nextDueOdometer = model.nextDueOdometer
        transactionID = model.transactionID
        createdAt = model.createdAt
        vehicleUID = model.vehicle?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: MaintenanceRecord) {
        model.uid = uid
        model.kindRaw = kindRaw
        model.title = title
        model.date = date
        model.odometer = odometer
        model.cost = cost
        model.currencyCode = currencyCode
        model.workshop = workshop
        model.notes = notes
        model.nextDueDate = nextDueDate
        model.nextDueOdometer = nextDueOdometer
        model.transactionID = transactionID
        model.createdAt = createdAt
    }
}

/// Cópia de `CarDeadline`.
nonisolated struct CarDeadlineRecord: Codable, Equatable, Sendable {
    var uid: String
    var kindRaw: String
    var title: String
    var dueDate: Date
    var amount: Decimal
    var currencyCode: String
    var renewalMonths: Int
    var notes: String
    var lastDoneAt: Date?
    var createdAt: Date
    var vehicleUID: String?
}

extension CarDeadlineRecord {
    @MainActor init(_ model: CarDeadline) {
        uid = model.uid
        kindRaw = model.kindRaw
        title = model.title
        dueDate = model.dueDate
        amount = model.amount
        currencyCode = model.currencyCode
        renewalMonths = model.renewalMonths
        notes = model.notes
        lastDoneAt = model.lastDoneAt
        createdAt = model.createdAt
        vehicleUID = model.vehicle?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: CarDeadline) {
        model.uid = uid
        model.kindRaw = kindRaw
        model.title = title
        model.dueDate = dueDate
        model.amount = amount
        model.currencyCode = currencyCode
        model.renewalMonths = renewalMonths
        model.notes = notes
        model.lastDoneAt = lastDoneAt
        model.createdAt = createdAt
    }
}

/// Cópia de `PersonalDocument`.
nonisolated struct PersonalDocumentRecord: Codable, Equatable, Sendable {
    var uid: String
    var title: String
    var kindRaw: String
    var number: String
    var issuer: String
    var expiryDate: Date?
    var remindDaysBefore: Int
    var notes: String
    var createdAt: Date
}

extension PersonalDocumentRecord {
    @MainActor init(_ model: PersonalDocument) {
        uid = model.uid
        title = model.title
        kindRaw = model.kindRaw
        number = model.number
        issuer = model.issuer
        expiryDate = model.expiryDate
        remindDaysBefore = model.remindDaysBefore
        notes = model.notes
        createdAt = model.createdAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: PersonalDocument) {
        model.uid = uid
        model.title = title
        model.kindRaw = kindRaw
        model.number = number
        model.issuer = issuer
        model.expiryDate = expiryDate
        model.remindDaysBefore = remindDaysBefore
        model.notes = notes
        model.createdAt = createdAt
    }
}

/// Cópia de `DocumentPhoto`.
nonisolated struct DocumentPhotoRecord: Codable, Equatable, Sendable {
    var uid: String
    var imageData: Data?
    var sortOrder: Int
    var createdAt: Date
    var documentUID: String?
}

extension DocumentPhotoRecord {
    @MainActor init(_ model: DocumentPhoto) {
        uid = model.uid
        imageData = model.imageData
        sortOrder = model.sortOrder
        createdAt = model.createdAt
        documentUID = model.document?.uid
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: DocumentPhoto) {
        model.uid = uid
        model.imageData = imageData
        model.sortOrder = sortOrder
        model.createdAt = createdAt
    }
}

/// Cópia de `JobApplication`.
nonisolated struct JobApplicationRecord: Codable, Equatable, Sendable {
    var uid: String
    var company: String
    var role: String
    var appliedAt: Date
    var statusRaw: String
    var statusChangedAt: Date
    var followUpDate: Date?
    var location: String
    var link: String
    var salary: String
    var contact: String
    var notes: String
    var createdAt: Date
}

extension JobApplicationRecord {
    @MainActor init(_ model: JobApplication) {
        uid = model.uid
        company = model.company
        role = model.role
        appliedAt = model.appliedAt
        statusRaw = model.statusRaw
        statusChangedAt = model.statusChangedAt
        followUpDate = model.followUpDate
        location = model.location
        link = model.link
        salary = model.salary
        contact = model.contact
        notes = model.notes
        createdAt = model.createdAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: JobApplication) {
        model.uid = uid
        model.company = company
        model.role = role
        model.appliedAt = appliedAt
        model.statusRaw = statusRaw
        model.statusChangedAt = statusChangedAt
        model.followUpDate = followUpDate
        model.location = location
        model.link = link
        model.salary = salary
        model.contact = contact
        model.notes = notes
        model.createdAt = createdAt
    }
}

/// Cópia de `Course`.
nonisolated struct CourseRecord: Codable, Equatable, Sendable {
    var uid: String
    var title: String
    var provider: String
    var statusRaw: String
    var progress: Double
    var completedAt: Date?
    var link: String
    var credentialID: String
    var expiresAt: Date?
    var notes: String
    var createdAt: Date
}

extension CourseRecord {
    @MainActor init(_ model: Course) {
        uid = model.uid
        title = model.title
        provider = model.provider
        statusRaw = model.statusRaw
        progress = model.progress
        completedAt = model.completedAt
        link = model.link
        credentialID = model.credentialID
        expiresAt = model.expiresAt
        notes = model.notes
        createdAt = model.createdAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Course) {
        model.uid = uid
        model.title = title
        model.provider = provider
        model.statusRaw = statusRaw
        model.progress = progress
        model.completedAt = completedAt
        model.link = link
        model.credentialID = credentialID
        model.expiresAt = expiresAt
        model.notes = notes
        model.createdAt = createdAt
    }
}

/// Cópia de `Investment`.
nonisolated struct InvestmentRecord: Codable, Equatable, Sendable {
    var uid: String
    var name: String
    var ticker: String
    var kindRaw: String
    var currencyCode: String
    var units: Double
    var investedAmount: Decimal
    var unitPrice: Decimal
    var priceUpdatedAt: Date?
    var manualValue: Decimal
    var isArchived: Bool
    var notes: String
    var createdAt: Date
}

extension InvestmentRecord {
    @MainActor init(_ model: Investment) {
        uid = model.uid
        name = model.name
        ticker = model.ticker
        kindRaw = model.kindRaw
        currencyCode = model.currencyCode
        units = model.units
        investedAmount = model.investedAmount
        unitPrice = model.unitPrice
        priceUpdatedAt = model.priceUpdatedAt
        manualValue = model.manualValue
        isArchived = model.isArchived
        notes = model.notes
        createdAt = model.createdAt
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: Investment) {
        model.uid = uid
        model.name = name
        model.ticker = ticker
        model.kindRaw = kindRaw
        model.currencyCode = currencyCode
        model.units = units
        model.investedAmount = investedAmount
        model.unitPrice = unitPrice
        model.priceUpdatedAt = priceUpdatedAt
        model.manualValue = manualValue
        model.isArchived = isArchived
        model.notes = notes
        model.createdAt = createdAt
    }
}

/// Cópia de `WealthSnapshot`.
nonisolated struct WealthSnapshotRecord: Codable, Equatable, Sendable {
    var day: Date
    var cash: Decimal
    var invested: Decimal
    var investmentsValue: Decimal
}

extension WealthSnapshotRecord {
    @MainActor init(_ model: WealthSnapshot) {
        day = model.day
        cash = model.cash
        invested = model.invested
        investmentsValue = model.investmentsValue
    }

    /// Copia os valores (sem as relações) para o modelo.
    @MainActor func apply(to model: WealthSnapshot) {
        model.day = day
        model.cash = cash
        model.invested = invested
        model.investmentsValue = investmentsValue
    }
}
