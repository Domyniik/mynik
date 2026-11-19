import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct BillTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar(identifier: .gregorian)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func recurrenceAdvancesByPeriod() {
        let start = date(2026, 11, 20)
        #expect(BillRecurrence.none.nextDate(after: start, calendar: calendar) == nil)
        #expect(BillRecurrence.weekly.nextDate(after: start, calendar: calendar) == date(2026, 11, 27))
        #expect(BillRecurrence.monthly.nextDate(after: start, calendar: calendar) == date(2026, 12, 20))
        #expect(BillRecurrence.yearly.nextDate(after: start, calendar: calendar) == date(2027, 11, 20))
    }

    @Test func payingRecurringBillCreatesExpenseAndAdvancesDueDate() throws {
        let category = Mynik.Category(name: "Casa", symbolName: "house", color: .brown, kind: .expense)
        let bill = Bill(title: "Renda", amount: 750, dueDate: date(2026, 11, 20), recurrence: .monthly, category: category)
        context.insert(bill)

        let transaction = BillPaymentService.markPaid(bill, on: date(2026, 11, 19), in: context, calendar: calendar)
        try context.save()

        #expect(transaction.title == "Renda")
        #expect(transaction.amount == 750)
        #expect(transaction.kind == .expense)
        #expect(transaction.category?.name == "Casa")
        #expect(transaction.date == date(2026, 11, 19))
        #expect(!bill.isPaid)
        #expect(bill.paidAt == date(2026, 11, 19))
        #expect(bill.dueDate == date(2026, 12, 20))
        #expect(try context.fetchCount(FetchDescriptor<FinanceTransaction>()) == 1)
    }

    @Test func payingOneOffBillClosesIt() {
        let bill = Bill(title: "ITV", amount: 40, dueDate: date(2026, 11, 25))
        context.insert(bill)

        BillPaymentService.markPaid(bill, on: date(2026, 11, 24), in: context, calendar: calendar)

        #expect(bill.isPaid)
        #expect(bill.dueDate == date(2026, 11, 25))
    }

    @Test func draftRoundTrip() {
        var draft = BillDraft()
        #expect(!draft.isValid)
        draft.title = " Luz "
        draft.amount = 45.30
        draft.recurrence = .monthly

        let bill = draft.makeBill()
        #expect(bill.title == "Luz")
        #expect(bill.recurrence == .monthly)
        #expect(BillDraft(bill).amount == 45.30)
    }
}
