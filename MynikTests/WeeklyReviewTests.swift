import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct WeeklyReviewTests {
    private let container: ModelContainer
    private let calendar = Calendar.mondayFirst
    /// Domingo, 22 nov. 2026, 18:00.
    private var sunday: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 18))! }

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: sunday)!
    }

    @Test func sundayIsReviewDay() {
        #expect(WeeklyReview.isReviewDay(sunday, calendar: calendar))
        #expect(!WeeklyReview.isReviewDay(day(-1), calendar: calendar))
    }

    @Test func summarizesTheWeekFromMondayToSunday() throws {
        let context = container.mainContext
        let food = try #require(QuickEntryService.category(matching: "Alimentação", in: context))
        context.insert(FinanceTransaction(title: "Mercadona", amount: 40, kind: .expense, date: day(-6), category: food)) // segunda
        context.insert(FinanceTransaction(title: "Cinema", amount: 10, kind: .expense, date: day(0)))
        context.insert(FinanceTransaction(title: "Semana passada", amount: 25, kind: .expense, date: day(-7))) // domingo anterior
        context.insert(FinanceTransaction(title: "Salário", amount: 1000, kind: .income, date: day(-3)))

        let paid = Bill(title: "Luz", amount: 50, dueDate: day(-2))
        paid.isPaid = true
        paid.paidAt = day(-2)
        context.insert(paid)
        context.insert(Bill(title: "Renda", amount: 700, dueDate: day(3)))
        context.insert(Bill(title: "Seguro", amount: 300, dueDate: day(20)))

        let task = ProjectTask(title: "Fase 7")
        task.status = .done
        task.completedAt = day(-1)
        context.insert(task)

        let habit = Habit(name: "Ler", targetPerWeek: 2)
        context.insert(habit)
        context.insert(HabitCheck(day: calendar.startOfDay(for: day(-1)), habit: habit))
        context.insert(HabitCheck(day: calendar.startOfDay(for: day(-4)), habit: habit))
        try context.save()

        let review = WeeklyReview(context: context, now: sunday, calendar: calendar)
        #expect(review.expenses == 50)
        #expect(review.previousExpenses == 25)
        #expect(review.expenseChange == 1)
        #expect(review.income == 1000)
        #expect(review.topCategories.first == .init(name: "Alimentação", amount: 40))
        #expect(review.billsPaid == 1)
        #expect(review.billsNextWeek == 1)
        #expect(review.billsNextWeekTotal == 700)
        #expect(review.tasksCompleted == 1)
        #expect(review.habits == [.init(name: "Ler", done: 2, target: 2)])
        #expect(review.habitsOnTrack == 1)
    }
}
