import Foundation
import SwiftData
import Testing
@testable import Mynik

/// Paridade com o servidor: o código Swift, com os dados de `parity-fixture.json`,
/// tem de dar os mesmos números que as funções SQL do Supabase
/// (`parity-expected.json`, gerado por `supabase/tests/parity.test.mjs`).
/// Assim o iPhone (offline) e o desktop (que lê do Supabase) mostram o mesmo score,
/// o mesmo lucro real e o mesmo orçamento.
@MainActor
struct ParityTests {
    private final class BundleToken {}

    private struct Fixture: Decodable {
        let now: Date
        let timeZone: String
        let settings: [String: Double]
        let archive: BackupArchive
    }

    private struct Expected: Decodable {
        struct Factor: Decodable { let kind: String; let points: Double; let hasData: Bool }
        struct Product: Decodable {
            let productID: String
            let score: Int
            let classification: String
            let action: String
            let ageDays: Int
            let units: Int
            let orderedUnits: Int
            let refundedUnits: Int
            let revenue: String
            let daysSinceLastSale: Int?
            let daysOfStock: Int?
            let abandonedUnits: Int?
            let marginRate: Double?
            let refundRate: Double
            let roas: Double?
            let checkoutConversion: Double?
            let factors: [Factor]
        }
        struct KPI: Decodable {
            let orders: Int
            let units: Int
            let grossSales: String
            let vat: String
            let productCosts: String
            let shippingCosts: String
            let paymentFees: String
            let adSpend: String
            let profit: String
            let margin: Double?
            let averageOrderValue: String?
            let sessions: Int
            let completedSessions: Int
            let hasTraffic: Bool
            let conversionRate: Double?
        }
        struct BudgetLine: Decodable {
            let categoryID: String
            let budget: String
            let spent: String
            let remaining: String
            let overBudget: Bool
            let progress: Double
        }
        struct Month: Decodable { let income: String; let expenses: String; let balance: String }

        let products: [Product]
        let kpis: [String: [String: KPI]]
        let budget: [BudgetLine]
        let months: [String: Month]
    }

    private let fixture: Fixture
    private let expected: Expected
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar: Calendar

    init() throws {
        let bundle = Bundle(for: BundleToken.self)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let fixtureURL = try #require(bundle.url(forResource: "parity-fixture", withExtension: "json"))
        let expectedURL = try #require(bundle.url(forResource: "parity-expected", withExtension: "json"))
        fixture = try decoder.decode(Fixture.self, from: Data(contentsOf: fixtureURL))
        expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: expectedURL))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: fixture.timeZone))
        self.calendar = calendar

        container = try ModelContainerFactory.make(inMemory: true)
        _ = try BackupService.importArchive(fixture.archive, into: container.mainContext)
    }

    private func fetch<M: PersistentModel>(_: M.Type) throws -> [M] {
        try context.fetch(FetchDescriptor<M>())
    }

    private func expectDecimal(_ actual: Decimal, _ expected: String, _ label: String) {
        #expect(actual.rounded(scale: 6) == Decimal(string: expected), "\(label): \(actual) ≠ \(expected)")
    }

    private func expectDouble(_ actual: Double?, _ expected: Double?, _ label: String) {
        switch (actual, expected) {
        case (nil, nil): break
        case let (a?, e?): #expect(abs(a - e) < 1e-8, "\(label): \(a) ≠ \(e)")
        default: Issue.record("\(label): \(String(describing: actual)) ≠ \(String(describing: expected))")
        }
    }

    // MARK: - Ranking

    @Test("Ranking de produtos: score, classificação, ação e fatores iguais ao SQL")
    func productScores() throws {
        let checkouts = try fetch(StoreCheckout.self)
        let performances = ProductPerformance.build(
            products: try fetch(StoreProduct.self),
            orders: try fetch(StoreOrder.self),
            abandonedUnitsByProduct: StoreOperations.abandonedUnitsByProduct(checkouts, now: fixture.now, calendar: calendar),
            now: fixture.now,
            calendar: calendar
        )
        let ranked = ProductScorer.rank(performances)
        #expect(ranked.map(\.performance.productID) == expected.products.map(\.productID))

        for (entry, want) in zip(ranked, expected.products) {
            let p = entry.performance, s = entry.score, id = want.productID
            #expect(s.score == want.score, "\(id) score")
            #expect(s.classification.rawValue == want.classification, "\(id) classificação")
            #expect(s.action == want.action, "\(id) ação")
            #expect(p.ageDays == want.ageDays, "\(id) idade")
            #expect(p.units == want.units && p.orderedUnits == want.orderedUnits && p.refundedUnits == want.refundedUnits, "\(id) unidades")
            expectDecimal(p.revenue, want.revenue, "\(id) receita")
            #expect(p.daysSinceLastSale == want.daysSinceLastSale, "\(id) dias sem venda")
            #expect(p.daysOfStock == want.daysOfStock, "\(id) dias de stock")
            #expect(p.abandonedUnits == want.abandonedUnits, "\(id) abandonadas")
            expectDouble(p.marginRate, want.marginRate, "\(id) margem")
            expectDouble(p.refundRate, want.refundRate, "\(id) reembolsos")
            expectDouble(p.roas, want.roas, "\(id) ROAS")
            expectDouble(p.checkoutConversion, want.checkoutConversion, "\(id) conversão")
            #expect(s.factors.map(\.kind.rawValue) == want.factors.map(\.kind), "\(id) fatores")
            for (factor, wanted) in zip(s.factors, want.factors) {
                expectDouble(factor.points, wanted.points, "\(id) \(wanted.kind)")
                #expect(factor.hasData == wanted.hasData, "\(id) \(wanted.kind) com dados")
            }
        }
    }

    // MARK: - Lucro real e KPIs

    @Test("KPIs e lucro real de hoje, 7 e 30 dias iguais ao SQL", arguments: [(StorePeriod.today, "1"), (.week, "7"), (.month, "30")])
    func kpis(period: StorePeriod, key: String) throws {
        let s = fixture.settings
        let costs = StoreCostSettings(
            paymentFeePercent: s["storeFeePercent"] ?? StoreCostSettings.defaultFeePercent,
            paymentFeeFixed: s["storeFeeFixed"] ?? StoreCostSettings.defaultFeeFixed,
            shippingCostPerOrder: s["storeShippingCost"] ?? StoreCostSettings.defaultShippingCost,
            monthlyAdSpend: s["storeMonthlyAds"] ?? 0,
            googleAdsUnattributed: s["googleAdsUnattributed30d"] ?? 0
        )
        let metrics = StoreMetrics(
            orders: try fetch(StoreOrder.self),
            stats: try fetch(DailyStat.self),
            products: try fetch(StoreProduct.self),
            costs: costs,
            calendar: calendar
        )
        let kpis = metrics.kpis(for: period, now: fixture.now)
        let wanted = try #require(expected.kpis[key])
        for (name, values) in [("current", kpis.current), ("previous", kpis.previous)] {
            let want = try #require(wanted[name])
            let label = "\(key) dias \(name)"
            #expect(values.orders == want.orders && values.units == want.units, "\(label) pedidos")
            let b = values.breakdown
            expectDecimal(b.grossSales, want.grossSales, "\(label) vendas")
            expectDecimal(b.vat, want.vat, "\(label) IVA")
            expectDecimal(b.productCosts, want.productCosts, "\(label) artigos")
            expectDecimal(b.shippingCosts, want.shippingCosts, "\(label) envio")
            expectDecimal(b.paymentFees, want.paymentFees, "\(label) taxas")
            expectDecimal(b.adSpend, want.adSpend, "\(label) anúncios")
            expectDecimal(b.profit, want.profit, "\(label) lucro")
            expectDouble(b.margin, want.margin, "\(label) margem")
            if let aov = want.averageOrderValue {
                expectDecimal(try #require(values.averageOrderValue), aov, "\(label) ticket médio")
            } else {
                #expect(values.averageOrderValue == nil)
            }
            #expect(values.sessions == want.sessions && values.completedSessions == want.completedSessions, "\(label) sessões")
            #expect(values.hasTraffic == want.hasTraffic, "\(label) tráfego")
            expectDouble(values.conversionRate, want.conversionRate, "\(label) conversão")
        }
    }

    // MARK: - Finanças

    private var converter: CurrencyConverter {
        CurrencyConverter(storedRate: fixture.settings["brlPerEUR"] ?? CurrencyConverter.defaultBRLPerEUR)
    }

    private func month(_ year: Int, _ month: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: 15, hour: 12)))
    }

    @Test("Orçamento por categoria igual ao SQL")
    func budget() throws {
        let overview = BudgetOverview(
            month: try month(2026, 11),
            categories: try fetch(Category.self),
            transactions: try fetch(FinanceTransaction.self),
            converter: converter,
            calendar: calendar
        )
        #expect(overview.lines.count == expected.budget.count)
        for want in expected.budget {
            let line = try #require(overview.lines.first { $0.category.uid == want.categoryID }, "\(want.categoryID)")
            expectDecimal(line.budget, want.budget, "\(want.categoryID) orçamento")
            expectDecimal(line.spent, want.spent, "\(want.categoryID) gasto")
            expectDecimal(line.remaining, want.remaining, "\(want.categoryID) restante")
            #expect(line.isOverBudget == want.overBudget, "\(want.categoryID) excedido")
            expectDouble(line.progress, want.progress, "\(want.categoryID) progresso")
        }
    }

    @Test("Receitas, gastos e saldo do mês iguais ao SQL", arguments: [(2026, 10), (2026, 11)])
    func monthSummary(year: Int, month monthNumber: Int) throws {
        let summary = MonthSummary(
            month: try month(year, monthNumber),
            transactions: try fetch(FinanceTransaction.self),
            converter: converter,
            calendar: calendar
        )
        let want = try #require(expected.months[String(format: "%04d-%02d", year, monthNumber)])
        expectDecimal(summary.income, want.income, "receitas")
        expectDecimal(summary.expenses, want.expenses, "gastos")
        expectDecimal(summary.balance, want.balance, "saldo")
    }
}
