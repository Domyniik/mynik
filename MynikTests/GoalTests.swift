import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct GoalTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar(identifier: .gregorian)
    private let converter = CurrencyConverter(brlPerEUR: 6)
    private let now: Date

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10)) ?? .now
    }

    private func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? now
    }

    @Test func manualGoalProgressAndMonthlyPace() {
        let goal = Goal(title: "Viagem", targetAmount: 1000, deadline: date(4, 10, year: 2027))
        goal.manualAmount = 400

        let progress = GoalProgress(goal: goal, converter: converter, now: now, calendar: calendar)
        #expect(progress.current == 400)
        #expect(progress.fraction == 0.4)
        #expect(progress.remaining == 600)
        // 20 nov → 10 abr: 4 meses e 21 dias → 5 meses.
        #expect(progress.monthsLeft == 5)
        #expect(progress.monthlyNeeded == 120)
        #expect(!progress.isReached)
    }

    @Test func reachedAndPastDeadline() {
        let reached = GoalProgress(current: 1200, target: 1000, monthsLeft: 3, isPastDeadline: false)
        #expect(reached.isReached)
        #expect(reached.fraction == 1)
        #expect(reached.remaining == 0)
        #expect(reached.monthlyNeeded == nil)

        let goal = Goal(title: "Carro", targetAmount: 5000, deadline: date(11, 1))
        let late = GoalProgress(goal: goal, converter: converter, now: now, calendar: calendar)
        #expect(late.isPastDeadline)
        #expect(late.monthsLeft == nil)
    }

    @Test func accountGoalFollowsBalanceInGoalCurrency() throws {
        let savings = Account(name: "Poupança BR", type: .savings, currencyCode: "BRL", initialBalance: 600)
        context.insert(savings)
        context.insert(FinanceTransaction(title: "Depósito", amount: 600, kind: .income, currencyCode: "BRL", account: savings))
        let goal = Goal(title: "Fundo", targetAmount: 1000, source: .account, account: savings)
        context.insert(goal)
        try context.save()

        #expect(GoalProgress.savedAmount(for: goal, converter: converter) == 200)
        #expect(!GoalContributionService.acceptsContributions(goal))
    }

    @Test func categoryGoalSumsMovementsSinceStart() throws {
        let category = Category(name: "Poupança", symbolName: "banknote", color: .green, kind: .expense)
        context.insert(category)
        let goal = Goal(title: "Portátil", targetAmount: 900, source: .category, startDate: date(11, 1), category: category)
        context.insert(goal)
        context.insert(FinanceTransaction(title: "Antes", amount: 50, kind: .expense, date: date(10, 30), category: category))
        context.insert(FinanceTransaction(title: "Novembro", amount: 100, kind: .expense, date: date(11, 5), category: category))
        context.insert(FinanceTransaction(title: "Em reais", amount: 300, kind: .expense, date: date(11, 6), currencyCode: "BRL", category: category))
        try context.save()

        #expect(GoalProgress.savedAmount(for: goal, converter: converter, calendar: calendar) == 150)
        #expect(GoalProgress.contributions(for: goal, calendar: calendar).map(\.title) == ["Em reais", "Novembro"])
    }

    @Test func contributionsUpdateManualOrCreateTransaction() throws {
        let manual = Goal(title: "Prenda", targetAmount: 100)
        context.insert(manual)
        #expect(GoalContributionService.contribute(30, to: manual, account: nil, in: context) == nil)
        #expect(manual.manualAmount == 30)

        let category = Category(name: "Poupança", symbolName: "banknote", color: .green, kind: .expense)
        let account = Account(name: "Conta principal")
        context.insert(category)
        context.insert(account)
        let linked = Goal(title: "Viagem", targetAmount: 500, source: .category, startDate: date(11, 1), category: category)
        context.insert(linked)

        let transaction = try #require(GoalContributionService.contribute(80, to: linked, account: account, date: date(11, 20), in: context))
        try context.save()
        #expect(transaction.title == "Meta: Viagem")
        #expect(transaction.kind == .expense)
        #expect(transaction.category === category)
        #expect(transaction.account === account)
        #expect(GoalProgress.savedAmount(for: linked, converter: converter, calendar: calendar) == 80)
        #expect(GoalContributionService.contribute(0, to: linked, account: account, in: context) == nil)
    }

    @Test func draftKeepsOnlyTheLinkTheSourceUses() {
        let category = Category(name: "Lazer", symbolName: "gamecontroller", color: .purple, kind: .expense)
        var draft = GoalDraft()
        draft.title = "Concerto"
        draft.targetAmount = 80
        draft.source = .manual
        draft.category = category
        let goal = draft.makeGoal()
        #expect(goal.category == nil)

        draft.source = .category
        #expect(draft.isValid)
        draft.apply(to: goal)
        #expect(goal.category === category)

        draft.source = .account
        #expect(!draft.isValid)
    }

    @Test func deletingAccountKeepsGoal() throws {
        let account = Account(name: "Poupança")
        context.insert(account)
        let goal = Goal(title: "Fundo", targetAmount: 1000, source: .account, account: account)
        context.insert(goal)
        try context.save()

        context.delete(account)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Goal>()).first?.account == nil)
        #expect(GoalProgress.savedAmount(for: goal, converter: converter) == 0)
    }
}
