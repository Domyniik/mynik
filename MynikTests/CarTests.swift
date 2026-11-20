import Foundation
import SwiftData
import Testing
@testable import Mynik

struct FuelEconomyTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func fill(_ day: Int, _ km: Int, _ liters: Double, _ cost: Decimal, full: Bool = true) -> FuelEconomy.Fill {
        .init(date: start.addingTimeInterval(Double(day) * 86_400), odometer: km, quantity: liters, cost: cost, isFullTank: full)
    }

    @Test func consumptionBetweenFullTanksIncludesPartialFills() throws {
        let economy = FuelEconomy(fills: [
            fill(0, 10_000, 40, 60),
            fill(10, 10_300, 15, 24, full: false),
            fill(20, 10_600, 27, 42),
            fill(30, 11_100, 30, 48),
        ])
        #expect(economy.segments.count == 2)
        // 15 + 27 L em 600 km = 7 L/100 km; 30 L em 500 km = 6 L/100 km.
        #expect(abs(economy.segments[0].per100km - 7) < 0.001)
        #expect(abs((economy.lastPer100km ?? 0) - 6) < 0.001)
        // 72 L em 1100 km.
        #expect(abs((economy.averagePer100km ?? 0) - 72.0 / 1_100 * 100) < 0.001)
        #expect(economy.costPerKm == Decimal(114) / Decimal(1_100))
    }

    @Test func needsTwoFullTanks() {
        let economy = FuelEconomy(fills: [fill(0, 10_000, 40, 60, full: false), fill(5, 10_400, 30, 45)])
        #expect(economy.segments.isEmpty)
        #expect(economy.averagePer100km == nil)
        #expect(economy.costPerKm == nil)
    }
}

@MainActor
struct CarExpenseTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar(identifier: .gregorian)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    @Test func fuelEntryCreatesUpdatesAndRemovesCarExpense() throws {
        let car = Vehicle(name: "Golf")
        context.insert(car)
        let entry = FuelEntry(odometer: 85_000, quantity: 40, totalCost: 62.5, station: "Repsol")
        context.insert(entry)
        entry.vehicle = car

        CarExpenseService.sync(entry, post: true, in: context)
        try context.save()
        let transaction = try #require(LinkedTransactionService.existing(entry.transactionID, in: context))
        #expect(transaction.title == "Combustível · Repsol")
        #expect(transaction.amount == 62.5)
        #expect(transaction.kind == .expense)
        #expect(transaction.category?.name == "Carro")
        #expect(transaction.account != nil)

        entry.totalCost = 70
        CarExpenseService.sync(entry, post: true, in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<FinanceTransaction>()) == 1)
        #expect(transaction.amount == 70)

        CarExpenseService.delete(entry, in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<FinanceTransaction>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<FuelEntry>()) == 0)
    }

    @Test func turningPostingOffRemovesTheExpense() throws {
        let record = MaintenanceRecord(kind: .oil, cost: 90)
        context.insert(record)
        CarExpenseService.sync(record, post: true, in: context)
        #expect(!record.transactionID.isEmpty)

        CarExpenseService.sync(record, post: false, in: context)
        try context.save()
        #expect(record.transactionID.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<FinanceTransaction>()) == 0)
    }

    @Test func completingInsuranceRenewsOnAnniversaryAndPostsExpense() throws {
        let insurance = CarDeadline(kind: .insurance, dueDate: date(2026, 3, 1), amount: 350)
        context.insert(insurance)

        let transaction = CarExpenseService.complete(insurance, on: date(2026, 3, 20), amount: 380, in: context, calendar: calendar)
        try context.save()
        #expect(transaction?.amount == 380)
        #expect(transaction?.category?.name == "Carro")
        #expect(insurance.amount == 380)
        #expect(calendar.isDate(insurance.dueDate, inSameDayAs: date(2027, 3, 1)))
    }

    @Test func inspectionRenewsFromCompletionDay() {
        let inspection = CarDeadline(kind: .inspection, dueDate: date(2026, 5, 1), renewalMonths: 24)
        let next = CarExpenseService.nextDueDate(for: inspection, completedOn: date(2026, 5, 20), calendar: calendar)
        #expect(next.map { calendar.isDate($0, inSameDayAs: date(2028, 5, 20)) } == true)

        let once = CarDeadline(kind: .other, title: "Revisão da garantia", dueDate: date(2026, 5, 1), renewalMonths: 0)
        #expect(CarExpenseService.nextDueDate(for: once, completedOn: date(2026, 5, 1), calendar: calendar) == nil)
    }

    @Test func agendaListsDeadlinesAndMaintenanceByKilometres() throws {
        let car = Vehicle(name: "Golf", initialOdometer: 99_500)
        context.insert(car)
        let itv = CarDeadline(kind: .inspection, dueDate: date(2026, 12, 1))
        context.insert(itv)
        itv.vehicle = car
        let oil = MaintenanceRecord(kind: .oil, date: date(2026, 1, 10), odometer: 90_000)
        oil.nextDueOdometer = 100_000
        context.insert(oil)
        oil.vehicle = car
        let tyres = MaintenanceRecord(kind: .tyres, date: date(2026, 1, 10), odometer: 90_000)
        tyres.nextDueOdometer = 130_000
        context.insert(tyres)
        tyres.vehicle = car
        try context.save()

        let now = date(2026, 11, 20)
        let items = LifeAgenda.carItems([car], now: now)
        #expect(items.count == 2)
        #expect(items.contains { $0.title == "ITV (inspeção)" && $0.detail == "Golf" })
        let oilItem = try #require(items.first { $0.title == "Mudança de óleo" })
        #expect(oilItem.detail == "Golf · faltam 500 km")
        #expect(items.upcoming(from: now, calendar: calendar).first?.title == "Mudança de óleo")
    }
}

struct AgendaTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10)) ?? .now
    }

    private func item(_ days: Int, remind: [Int] = [30, 7, 0], horizon: Int = 30) -> AgendaItem {
        AgendaItem(
            id: "x",
            title: "ITV",
            detail: "Golf",
            date: calendar.date(byAdding: .day, value: days, to: now) ?? now,
            symbolName: "car",
            source: .car,
            horizonDays: horizon,
            remindDaysBefore: remind
        )
    }

    @Test func describesAndFiltersByHorizon() {
        #expect(item(0).describe(from: now, calendar: calendar) == "Vence hoje")
        #expect(item(12).describe(from: now, calendar: calendar) == "Vence em 12 dias")
        #expect(item(-2).describe(from: now, calendar: calendar) == "Atrasado 2 dias")
        #expect([item(45), item(3)].upcoming(from: now, calendar: calendar).count == 1)
    }

    @Test func remindersOnlyInTheFuture() {
        let planner = AgendaReminderPlanner(calendar: calendar)
        // A 10 dias: o aviso de 30 dias já passou; ficam o de 7 dias e o do dia.
        let reminders = planner.reminders(for: [item(10)], now: now)
        #expect(reminders.map(\.title) == ["ITV: vence em 7 dias", "ITV: vence hoje"])
        #expect(reminders.allSatisfy { $0.identifier.hasPrefix(AgendaReminderPlanner.identifierPrefix) })
        #expect(reminders.first?.body == "Golf")
    }
}

struct FuelPriceTests {
    private let json = """
    {"Fecha":"20/11/2026 15:33:24","ListaEESSPrecio":[
      {"IDEESS":"1","Rótulo":"REPSOL","Dirección":"CALLE MAYOR 1","Localidad":"MADRID","Latitud":"40,416775","Longitud (WGS84)":"-3,703790",
       "Precio Gasolina 95 E5":"1,645","Precio Gasoleo A":"1,559","Precio Gasolina 98 E5":""},
      {"IDEESS":"2","Rótulo":"BALLENOIL","Dirección":"AV. EUROPA 4","Localidad":"POZUELO","Latitud":"40,435","Longitud (WGS84)":"-3,812",
       "Precio Gasolina 95 E5":"1,489","Precio Gasoleo A":null},
      {"IDEESS":"3","Rótulo":"LEJOS","Dirección":"","Localidad":"ARANJUEZ","Latitud":"40,03","Longitud (WGS84)":"-3,60",
       "Precio Gasolina 95 E5":"1,399"},
      {"IDEESS":"4","Rótulo":"SIN PRECIOS","Latitud":"40,4","Longitud (WGS84)":"-3,7"}
    ],"Nota":"","ResultadoConsulta":"OK"}
    """

    @Test func decodesStationsWithCommaDecimals() throws {
        let snapshot = try FuelPriceService.decode(Data(json.utf8), provinceID: "28")
        #expect(snapshot.stations.count == 3)
        let repsol = try #require(snapshot.stations.first { $0.id == "1" })
        #expect(repsol.brand == "Repsol")
        #expect(repsol.town == "Madrid")
        #expect(repsol.price(for: .gasoline95) == Decimal(string: "1.645"))
        #expect(repsol.price(for: .diesel) == Decimal(string: "1.559"))
        #expect(repsol.price(for: .gasoline98) == nil)
        #expect(abs(repsol.latitude - 40.416775) < 0.000_001)
        #expect(snapshot.publishedAt != nil)
    }

    @Test func ranksCheapestNearbyThenFallsBackToAll() throws {
        let stations = try FuelPriceService.decode(Data(json.utf8), provinceID: "28").stations
        let sol = FuelPriceRanking.Coordinate(latitude: 40.4168, longitude: -3.7038)

        // Aranjuez fica a ~43 km: fora do raio de 10 km.
        let nearby = FuelPriceRanking.cheapest(stations, fuel: .gasoline95, near: sol)
        #expect(nearby.map(\.station.id) == ["2", "1"])
        #expect((nearby.last?.distance ?? 99) < 0.1)

        let all = FuelPriceRanking.cheapest(stations, fuel: .gasoline95)
        #expect(all.map(\.station.id) == ["3", "2", "1"])
        #expect(FuelPriceRanking.cheapest(stations, fuel: .diesel, near: sol, radius: 1).map(\.station.id) == ["1"])
        let expected = (Decimal(string: "1.645")! + Decimal(string: "1.489")! + Decimal(string: "1.399")!) / 3
        #expect(FuelPriceRanking.average(stations, fuel: .gasoline95) == expected)
    }

    @Test func cacheRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "fuel-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let snapshot = try FuelPriceService.decode(Data(json.utf8), provinceID: "28")
        FuelPriceCache.save(snapshot, folder: folder)
        let loaded = try #require(FuelPriceCache.load(provinceID: "28", folder: folder))
        #expect(loaded.stations == snapshot.stations)
        #expect(FuelPriceCache.load(provinceID: "08", folder: folder) == nil)
    }
}
