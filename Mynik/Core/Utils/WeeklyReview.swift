import Foundation
import SwiftData

/// Revisão da semana (segunda a domingo): dinheiro, contas, tarefas, hábitos e loja.
///
/// Pensada para domingo, mas pode abrir-se em qualquer dia (mostra a semana atual).
struct WeeklyReview {
    struct HabitLine: Equatable {
        let name: String
        let done: Int
        let target: Int
    }

    struct CategoryLine: Equatable {
        let name: String
        let amount: Decimal
    }

    let week: DateInterval
    var expenses: Decimal = 0
    var previousExpenses: Decimal = 0
    var income: Decimal = 0
    var topCategories: [CategoryLine] = []
    var billsPaid = 0
    var billsNextWeek = 0
    var billsNextWeekTotal: Decimal = 0
    var tasksCompleted = 0
    var habits: [HabitLine] = []
    var storeSales: Decimal = 0
    var storeOrders = 0

    /// Variação dos gastos face à semana anterior (`nil` sem base de comparação).
    var expenseChange: Double? {
        guard previousExpenses > 0 else { return nil }
        return NSDecimalNumber(decimal: (expenses - previousExpenses) / previousExpenses).doubleValue
    }

    var habitsOnTrack: Int { habits.filter { $0.done >= $0.target }.count }

    static func isReviewDay(_ date: Date = .now, calendar: Calendar = .mondayFirst) -> Bool {
        calendar.component(.weekday, from: date) == 1 // domingo
    }

    init(
        context: ModelContext,
        converter: CurrencyConverter = CurrencyConverter(),
        now: Date = .now,
        calendar: Calendar = .mondayFirst
    ) {
        let today = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: today) ?? DateInterval(start: today, duration: 7 * 86_400)
        self.week = week
        let previousStart = calendar.date(byAdding: .day, value: -7, to: week.start) ?? week.start
        let nextEnd = calendar.date(byAdding: .day, value: 7, to: week.end) ?? week.end
        func inWeek(_ date: Date) -> Bool { date >= week.start && date < week.end }
        func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }

        // Finanças
        var byCategory: [String: Decimal] = [:]
        for transaction in fetch(FinanceTransaction.self) {
            let amount = converter.amountInDefaultCurrency(transaction)
            if inWeek(transaction.date) {
                switch transaction.kind {
                case .expense:
                    expenses += amount
                    byCategory[transaction.category?.name ?? FinanceReport.uncategorizedName, default: 0] += amount
                case .income:
                    income += amount
                }
            } else if transaction.kind == .expense, transaction.date >= previousStart, transaction.date < week.start {
                previousExpenses += amount
            }
        }
        topCategories = byCategory
            .map { CategoryLine(name: $0.key, amount: $0.value) }
            .sorted { $0.amount == $1.amount ? $0.name < $1.name : $0.amount > $1.amount }
            .prefix(3)
            .map { $0 }

        // Contas
        for bill in fetch(Bill.self) {
            if bill.isPaid, let paidAt = bill.paidAt, inWeek(paidAt) {
                billsPaid += 1
            } else if !bill.isPaid, bill.dueDate >= week.end, bill.dueDate < nextEnd {
                billsNextWeek += 1
                billsNextWeekTotal += converter.convert(bill.amount, from: bill.currencyCode)
            }
        }

        // Tarefas
        tasksCompleted = fetch(ProjectTask.self).filter { task in
            task.isDone && task.completedAt.map(inWeek) == true
        }.count

        // Hábitos
        habits = fetch(Habit.self)
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { habit in
                HabitLine(name: habit.name, done: (habit.checks ?? []).filter { inWeek($0.day) }.count, target: habit.targetPerWeek)
            }

        // Loja
        for order in fetch(StoreOrder.self) where !order.isCancelled && inWeek(order.createdAt) {
            storeSales += order.total
            storeOrders += 1
        }
    }
}
