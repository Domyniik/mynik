import Foundation
import SwiftData
import Testing
@testable import Mynik

struct QuestionRouterTests {
    @Test(arguments: [
        ("Quanto gastei este mês?", QuestionRouter.Route.finances(monthsAgo: 0)),
        ("Qual foi o saldo do mês passado?", .finances(monthsAgo: 1)),
        ("Quanto gastei em Mercadona?", .spending(query: "mercadona", monthsAgo: 0)),
        ("Quanto gastei com alimentação no mês passado?", .spending(query: "alimentacao", monthsAgo: 1)),
        ("Que contas vencem esta semana?", .bills(days: 7)),
        ("Como correu a loja hoje?", .store(.today)),
        ("Quantas vendas nos últimos 30 dias?", .store(.month)),
        ("Qual é o consumo do carro?", .life(.car)),
        ("O passaporte expira quando?", .life(.documents)),
        ("Como estão as minhas metas?", .life(.goals)),
        ("Qual é o meu património?", .life(.wealth)),
        ("Conta-me uma piada", .unknown),
    ])
    func routes(question: String, expected: QuestionRouter.Route) {
        #expect(QuestionRouter.route(question) == expected)
    }
}

@MainActor
struct MynikDataDigestTests {
    private let container: ModelContainer
    private let now = Date(timeIntervalSince1970: 1_800_000_000) // jan. 2027

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }

    private var digest: MynikDataDigest {
        MynikDataDigest(context: container.mainContext, now: now, defaults: AppEnvironment.testDefaults)
    }

    @Test func summarizesMonthWithCategories() throws {
        let context = container.mainContext
        let food = try #require(QuickEntryService.category(matching: "Alimentação", in: context))
        context.insert(FinanceTransaction(title: "Mercadona", amount: 42.5, kind: .expense, date: now, category: food))
        context.insert(FinanceTransaction(title: "Salário", amount: 1500, kind: .income, date: now))
        try context.save()

        let text = digest.finances()
        #expect(text.contains("Receitas: 1500,00"))
        #expect(text.contains("Gastos: 42,50"))
        #expect(text.contains("Alimentação 42,50"))
    }

    @Test func filtersSpendingByMerchantOrCategory() throws {
        let context = container.mainContext
        context.insert(FinanceTransaction(title: "Mercadona Valencia", amount: 10, kind: .expense, date: now))
        context.insert(FinanceTransaction(title: "Mercadona Madrid", amount: 15, kind: .expense, date: now))
        context.insert(FinanceTransaction(title: "Repsol", amount: 50, kind: .expense, date: now))
        try context.save()

        let text = digest.spending(matching: "mercadona")
        #expect(text.contains("25,00"))
        #expect(text.contains("2 movimento"))
        #expect(digest.spending(matching: "Lidl").hasPrefix("Não há gastos"))
    }

    @Test func listsUnpaidBillsIncludingOverdue() throws {
        let context = container.mainContext
        let overdue = Bill(title: "Luz", amount: 60, dueDate: now.addingTimeInterval(-86_400 * 2))
        let paid = Bill(title: "Água", amount: 20, dueDate: now)
        paid.isPaid = true
        context.insert(overdue)
        context.insert(paid)
        try context.save()

        let text = digest.bills(days: 7)
        #expect(text.contains("Luz"))
        #expect(text.contains("em atraso"))
        #expect(!text.contains("Água"))
    }

    @Test func emptyDataGivesClearAnswers() {
        #expect(digest.bills().hasPrefix("Não há contas"))
        #expect(digest.store().contains("ainda não tem pedidos"))
        #expect(digest.life(topic: .car).contains("nenhum carro"))
        #expect(digest.life(topic: .goals) == "Não há metas ativas.")
    }

    @Test func modelAnswersNeedRealText() {
        #expect(AskMynikModel.isUsable("Gastaste 42,50 € este mês."))
        #expect(!AskMynikModel.isUsable("Vamos começar.\n\n[{}]"))
        #expect(!AskMynikModel.isUsable("  "))
        #expect(AskMynikModel.prompt("Olá", data: nil) == "Olá")
        #expect(AskMynikModel.prompt("Contas?", data: "Luz 60 €").contains("Luz 60 €"))
        #expect(AskMynikModel.relevantData(for: "conta-me uma piada", digest: digest) == nil)
    }

    @Test func offlineAnswerUsesRouter() {
        let answer = AskMynikModel.offlineAnswer("Que contas vencem?", digest: digest)
        #expect(answer.hasPrefix("Não há contas"))
        #expect(AskMynikModel.offlineAnswer("olá", digest: digest).contains("Sem a Apple Intelligence"))
    }
}
