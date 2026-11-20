import Foundation
import SwiftData
import Testing
@testable import Mynik

/// Respostas falsas para os pedidos de cotações (sem rede nos testes).
nonisolated private final class QuoteStubProtocol: URLProtocol, @unchecked Sendable {
    static let responses: [String: (Int, String)] = [
        "/v8/finance/chart/VWCE.DE": (200, #"{"chart":{"result":[{"meta":{"currency":"EUR","regularMarketPrice":160.5,"shortName":"Vanguard FTSE All-World"}}]}}"#),
        "/v8/finance/chart/AAPL": (200, #"{"chart":{"result":[{"meta":{"currency":"USD","regularMarketPrice":200.0,"shortName":"Apple Inc."}}]}}"#),
        "/v8/finance/chart/NOPE": (404, #"{"chart":{"result":null,"error":{"code":"Not Found"}}}"#),
        "/v1/latest": (200, #"{"amount":1.0,"base":"USD","date":"2026-11-19","rates":{"EUR":0.9}}"#),
    ]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let (status, body) = Self.responses[path] ?? (500, "")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QuoteStubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

struct QuoteServiceTests {
    @Test func decodesPriceAndConvertsPence() throws {
        let euro = try QuoteService.decode(Data(#"{"chart":{"result":[{"meta":{"currency":"EUR","regularMarketPrice":161.08,"shortName":"VWCE"}}]}}"#.utf8))
        #expect(euro == Quote(price: Decimal(string: "161.08")!, currency: "EUR", name: "VWCE"))

        let london = try QuoteService.decode(Data(#"{"chart":{"result":[{"meta":{"currency":"GBp","regularMarketPrice":8450}}]}}"#.utf8))
        #expect(london.price == 84.5)
        #expect(london.currency == "GBP")

        #expect(throws: QuoteService.ServiceError.notFound) {
            try QuoteService.decode(Data(#"{"chart":{"result":null}}"#.utf8))
        }
    }

    @Test func urlOnlyCarriesTheTicker() {
        #expect(QuoteService.url(for: " btc-eur ")?.absoluteString == "https://query1.finance.yahoo.com/v8/finance/chart/BTC-EUR?range=1d&interval=1d")
        #expect(QuoteService.url(for: "^GSPC")?.path == "/v8/finance/chart/^GSPC")
        #expect(QuoteService.url(for: "") == nil)
    }
}

@MainActor
struct InvestmentTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let converter = CurrencyConverter(brlPerEUR: 6)
    private let calendar = Calendar(identifier: .gregorian)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }

    @Test func valueUsesQuoteOrManualValue() {
        let etf = Investment(name: "All-World", kind: .etf, ticker: "VWCE.DE", units: 10, investedAmount: 1_500)
        etf.unitPrice = 160
        #expect(etf.currentValue == 1_600)
        #expect(etf.gain == 100)
        #expect(abs((etf.gainFraction ?? 0) - 0.0667) < 0.001)

        let deposit = Investment(name: "Depósito", kind: .deposit, investedAmount: 2_000)
        deposit.manualValue = 2_050
        #expect(deposit.currentValue == 2_050)
    }

    @Test func wealthSummaryAddsAccountsAndInvestmentsInEuros() {
        let account = Account(name: "Banco", initialBalance: 1_000)
        let brazil = Account(name: "Nubank", currencyCode: "BRL", initialBalance: 600)
        let etf = Investment(name: "All-World", kind: .etf, ticker: "VWCE.DE", units: 10, investedAmount: 1_500)
        etf.unitPrice = 160
        let archived = Investment(name: "Antigo", kind: .other, investedAmount: 999)
        archived.isArchived = true

        let summary = WealthSummary(accounts: [account, brazil], investments: [etf, archived], converter: converter)
        #expect(summary.cash == 1_100)
        #expect(summary.invested == 1_500)
        #expect(summary.investmentsValue == 1_600)
        #expect(summary.netWorth == 2_700)
        #expect(summary.gain == 100)
    }

    @Test func contributionPostsExpenseInInvestmentsCategory() throws {
        let account = try #require(try context.fetch(FetchDescriptor<Account>()).first)
        let etf = Investment(name: "All-World", kind: .etf, ticker: "VWCE.DE", units: 10, investedAmount: 1_500)
        context.insert(etf)

        let transaction = try #require(
            InvestmentService.contribute(200, units: 1.25, to: etf, account: account, postToFinance: true, in: context)
        )
        try context.save()
        #expect(etf.investedAmount == 1_700)
        #expect(etf.units == 11.25)
        #expect(transaction.kind == .expense)
        #expect(transaction.category?.name == "Investimentos")
        #expect(transaction.isAutomatic)

        // A categoria é criada uma só vez.
        InvestmentService.contribute(50, to: etf, account: account, postToFinance: true, in: context)
        try context.save()
        let name = InvestmentService.categoryName
        #expect(try context.fetchCount(FetchDescriptor<Mynik.Category>(predicate: #Predicate { $0.name == name })) == 1)

        let deposit = Investment(name: "Depósito", kind: .deposit, investedAmount: 1_000)
        deposit.manualValue = 1_000
        #expect(InvestmentService.contribute(500, to: deposit, account: nil, postToFinance: false, in: context) == nil)
        #expect(deposit.manualValue == 1_500)
    }

    @Test func savingsCountContributionsAsSaved() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20)) ?? .now
        let investments = InvestmentService.investmentsCategory(in: context)
        let transactions = [
            FinanceTransaction(title: "Salário", amount: 2_000, kind: .income, date: now),
            FinanceTransaction(title: "Renda", amount: 800, kind: .expense, date: now),
            FinanceTransaction(title: "Aporte", amount: 300, kind: .expense, date: now, category: investments),
            FinanceTransaction(title: "Outubro", amount: 500, kind: .expense, date: calendar.date(byAdding: .month, value: -1, to: now) ?? now),
        ]
        let progress = SavingsProgress(month: now, transactions: transactions, target: 1_000, converter: converter, calendar: calendar)
        #expect(progress.income == 2_000)
        #expect(progress.expenses == 1_100)
        #expect(progress.contributions == 300)
        #expect(progress.saved == 1_200)
        #expect(progress.rate == 0.6)
        #expect(progress.targetFraction == 1)
        #expect(progress.remainingToTarget == 0)
        #expect(SavingsProgress(income: 0, expenses: 10, target: 0).targetFraction == nil)
    }

    @Test func snapshotIsOnePerDay() throws {
        let etf = Investment(name: "All-World", kind: .etf, ticker: "VWCE.DE", units: 10, investedAmount: 1_500)
        etf.unitPrice = 150
        context.insert(etf)
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9)) ?? .now
        InvestmentService.recordSnapshot(in: context, converter: converter, now: morning, calendar: calendar)
        etf.unitPrice = 160
        InvestmentService.recordSnapshot(in: context, converter: converter, now: morning.addingTimeInterval(3_600 * 8), calendar: calendar)
        try context.save()

        let snapshots = try context.fetch(FetchDescriptor<WealthSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.investmentsValue == 1_600)
        #expect(snapshots.first?.invested == 1_500)
    }

    @Test func refreshesQuotesConvertingOtherCurrenciesAndKeepsOldPriceOnFailure() async throws {
        let etf = Investment(name: "All-World", kind: .etf, ticker: "VWCE.DE", units: 10)
        let apple = Investment(name: "Apple", kind: .stock, ticker: "AAPL", units: 2)
        let broken = Investment(name: "Erro", kind: .stock, ticker: "NOPE", units: 1)
        broken.unitPrice = 42
        let fresh = Investment(name: "Fresca", kind: .etf, ticker: "VWCE.DE", units: 1)
        fresh.unitPrice = 1
        let now = Date.now
        fresh.priceUpdatedAt = now

        let failed = await InvestmentService.refreshQuotes(
            [etf, apple, broken, fresh], converter: converter, session: QuoteStubProtocol.session, now: now
        )
        #expect(failed == ["NOPE"])
        #expect(etf.unitPrice == Decimal(string: "160.5"))
        // 200 USD × 0,9 = 180 EUR.
        #expect(apple.unitPrice == 180)
        #expect(broken.unitPrice == 42)
        // Cotação recente: não pede de novo.
        #expect(fresh.unitPrice == 1)
    }
}
