import Foundation
import SwiftData
import Testing
@testable import Mynik

struct HabitProgressTests {
    private let calendar = Calendar.mondayFirst
    /// Quarta-feira, 18 nov. 2026, 10:00.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10))! }

    private func days(_ offsets: [Int]) -> Set<Date> {
        Set(offsets.map { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now))! })
    }

    @Test func streakCountsConsecutiveDaysIncludingToday() {
        let progress = HabitProgress(days: days([0, -1, -2, -4]), targetPerWeek: 7, now: now, calendar: calendar)
        #expect(progress.streak == 3)
        #expect(progress.isDoneToday)
        #expect(progress.lastSevenDays == [false, false, true, false, true, true, true])
    }

    @Test func streakSurvivesUntilTodayIsMarked() {
        let progress = HabitProgress(days: days([-1, -2]), targetPerWeek: 7, now: now, calendar: calendar)
        #expect(progress.streak == 2)
        #expect(!progress.isDoneToday)
    }

    @Test func weekStartsOnMonday() {
        // Segunda (−2), terça (−1) e quarta (0) contam; domingo (−3) é da semana anterior.
        let progress = HabitProgress(days: days([0, -1, -2, -3]), targetPerWeek: 3, now: now, calendar: calendar)
        #expect(progress.thisWeek == 3)
        #expect(progress.isWeekGoalReached)
    }

    @Test func emptyHabit() {
        let progress = HabitProgress(days: [], targetPerWeek: 4, now: now, calendar: calendar)
        #expect(progress.streak == 0)
        #expect(progress.thisWeek == 0)
        #expect(!progress.isWeekGoalReached)
    }
}

@MainActor
struct HabitServiceTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
    }

    @Test func toggleMarksAndUnmarksTheDay() throws {
        let context = container.mainContext
        let habit = Habit(name: "Ler", targetPerWeek: 9)
        context.insert(habit)
        #expect(habit.targetPerWeek == 7)

        HabitService.toggle(habit, in: context)
        #expect(HabitService.isDone(habit))
        #expect(try context.fetchCount(FetchDescriptor<HabitCheck>()) == 1)

        HabitService.toggle(habit, in: context)
        #expect(!HabitService.isDone(habit))
        #expect(try context.fetchCount(FetchDescriptor<HabitCheck>()) == 0)
    }

    @Test func deletingHabitDeletesChecks() throws {
        let context = container.mainContext
        let habit = Habit(name: "Ginásio")
        context.insert(habit)
        HabitService.toggle(habit, in: context)
        context.delete(habit)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<HabitCheck>()) == 0)
    }

    @Test func migratesVersionFiveStoreOnDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "mynik-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")

        do {
            let schema = Schema(versionedSchema: MynikSchemaV5.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let transaction = MynikSchemaV5.FinanceTransaction()
            transaction.title = "Mercadona"
            transaction.uid = "abc"
            old.mainContext.insert(transaction)
            try old.mainContext.save()
        }

        let current = try ModelContainerFactory.make(url: url)
        let transactions = try current.mainContext.fetch(FetchDescriptor<FinanceTransaction>())
        #expect(transactions.map(\.uid) == ["abc"])
        #expect(try current.mainContext.fetchCount(FetchDescriptor<Habit>()) == 0)
    }
}
