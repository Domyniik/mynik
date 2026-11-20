import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct WidgetSnapshotTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_795_000_000) // novembro de 2026

    @Test func summarisesMonthAndUnpaidBills() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        context.insert(FinanceTransaction(title: "Salário", amount: 1500, kind: .income, date: now))
        context.insert(FinanceTransaction(title: "Mercado", amount: 200, kind: .expense, date: now))
        context.insert(FinanceTransaction(title: "Antigo", amount: 999, kind: .expense, date: lastMonth))
        context.insert(Bill(title: "Renda", amount: 750, dueDate: calendar.date(byAdding: .day, value: 2, to: now)!))
        context.insert(Bill(title: "Atrasada", amount: 20, dueDate: calendar.date(byAdding: .day, value: -3, to: now)!))
        context.insert(Bill(title: "Longe", amount: 5, dueDate: calendar.date(byAdding: .day, value: 60, to: now)!))
        let paid = Bill(title: "Paga", amount: 9, dueDate: now)
        paid.isPaid = true
        context.insert(paid)
        try context.save()

        let snapshot = try WidgetSnapshotWriter.makeSnapshot(in: context, converter: CurrencyConverter(), now: now, calendar: calendar)
        #expect(snapshot.income == 1500)
        #expect(snapshot.expenses == 200)
        #expect(snapshot.balance == 1300)
        #expect(snapshot.bills.map(\.title) == ["Atrasada", "Renda"])
        #expect(snapshot.bills(within: 1, from: now, calendar: calendar).map(\.title) == ["Atrasada"])
    }

    @Test func savesAndLoadsFromFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "widget-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try WidgetSnapshot.preview.save(to: url))
        #expect(WidgetSnapshot.load(from: url) == WidgetSnapshot.preview)
        #expect(WidgetSnapshot.load(from: nil) == nil)
    }
}
