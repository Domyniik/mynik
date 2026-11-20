import Foundation
import Testing
@testable import Mynik

@MainActor
struct ProductScorerTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func performance(
        _ title: String,
        age: Int = 60,
        units: Int = 30,
        refunded: Int = 0,
        revenue: Decimal = 900,
        price: Decimal = 30,
        cost: Decimal = 8,
        lastSale: Int? = 0,
        ads: Decimal = 0,
        inventory: Int = 100,
        abandoned: Int? = nil
    ) -> ProductPerformance {
        ProductPerformance(
            productID: title, title: title, price: price, unitCost: cost, ageDays: age,
            units: units, orderedUnits: units + refunded, refundedUnits: refunded, revenue: revenue,
            daysSinceLastSale: lastSale, adSpend: ads, inventory: inventory, tracksInventory: true,
            abandonedUnits: abandoned
        )
    }

    @Test func strongProductIsWinnerAndWeakIsLoser() {
        let ranking = ProductScorer.rank([
            performance("Fraco", units: 2, refunded: 2, revenue: 50, cost: 22, lastSale: 25, ads: 100),
            performance("Forte", units: 40, revenue: 1200, ads: 150),
        ])

        #expect(ranking.map(\.performance.title) == ["Forte", "Fraco"])
        #expect(ranking[0].score.classification == .winner)
        #expect(ranking[0].score.score >= ProductScorer.winnerThreshold)
        #expect(ranking[0].score.action.hasPrefix("Escalar"))
        #expect(ranking[1].score.classification == .loser)
        #expect(ranking[1].score.action == "Pausar os anúncios e tirar de destaque.")
    }

    @Test func scoreStaysWithinZeroAndHundred() {
        let best = performance("Perfeito", units: 50, revenue: 5000, cost: 1, ads: 100, abandoned: 0)
        let worst = performance("Mau", units: 0, refunded: 5, revenue: 0, cost: 40, lastSale: nil, ads: 100)
        for entry in ProductScorer.rank([best, worst]) {
            #expect((0...100).contains(entry.score.score))
            #expect(entry.score.factors.reduce(0) { $0 + $1.maxPoints } == 100)
        }
    }

    @Test func newOrLowDataProductsStayInTesting() {
        let ranking = ProductScorer.rank([
            performance("Novo", age: 5, units: 1, revenue: 30),
            performance("Poucos dados", age: 20, units: 1, revenue: 30),
            performance("Antigo parado", age: 90, units: 0, revenue: 0, lastSale: nil),
        ])
        let byTitle = Dictionary(uniqueKeysWithValues: ranking.map { ($0.performance.title, $0.score) })

        #expect(byTitle["Novo"]?.classification == .testing)
        #expect(byTitle["Novo"]?.action == "Manter o teste mais 9 dias antes de decidir.")
        #expect(byTitle["Poucos dados"]?.classification == .testing)
        #expect(byTitle["Antigo parado"]?.classification == .loser)
        #expect(byTitle["Antigo parado"]?.action == "Arquivar ou escoar o stock com desconto.")
    }

    @Test func winnerWithLowStockSuggestsRestock() {
        let score = ProductScorer.score(performance("Esgota", units: 30, inventory: 5), bestUnits: 30, totalRevenue: 900)
        #expect(score.classification == .winner)
        #expect(score.action == "Repor stock: ao ritmo atual só dá para 5 dias.")
    }

    @Test func promisingActionTargetsWeakestMeasuredFactor() {
        // Margem baixa (custo alto), resto razoável.
        let product = performance("Margem curta", units: 18, revenue: 540, cost: 21)
        let score = ProductScorer.score(product, bestUnits: 30, totalRevenue: 2000)
        #expect(score.classification == .promising)
        #expect(score.action == "Rever o preço ou o fornecedor para subir a margem.")
    }

    @Test func missingDataFactorsAreNeutral() {
        let score = ProductScorer.score(performance("Sem custo", cost: 0), bestUnits: 30, totalRevenue: 900)
        let margin = score.factors.first { $0.kind == .margin }
        #expect(margin?.hasData == false)
        #expect(margin?.points == 20 * ProductScorer.neutralRatio)
    }

    @Test func buildsPerformanceFromOrders() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12)) ?? .now
        let product = StoreProduct(shopifyID: "p1", title: "Colar", price: 20, unitCost: 5,
                                   createdAt: calendar.date(byAdding: .day, value: -40, to: now) ?? now)
        let draft = StoreProduct(shopifyID: "p2", title: "Rascunho")
        draft.statusRaw = "DRAFT"
        let recent = StoreOrder(shopifyID: "o1", name: "#1", createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                                lines: [StoreOrderLine(productID: "p1", title: "Colar", quantity: 3, currentQuantity: 2, unitPrice: 20)])
        let old = StoreOrder(shopifyID: "o2", name: "#2", createdAt: calendar.date(byAdding: .day, value: -45, to: now) ?? now,
                             lines: [StoreOrderLine(productID: "p1", title: "Colar", quantity: 1, currentQuantity: 1, unitPrice: 20)])

        let result = ProductPerformance.build(products: [product, draft], orders: [recent, old],
                                              abandonedUnitsByProduct: ["p1": 4], now: now, calendar: calendar)

        #expect(result.count == 1)
        let colar = result[0]
        #expect(colar.ageDays == 40)
        #expect(colar.units == 2)
        #expect(colar.orderedUnits == 3)
        #expect(colar.refundedUnits == 1)
        #expect(colar.revenue == 40)
        #expect(colar.daysSinceLastSale == 2)
        #expect(colar.marginRate == 0.75)
        #expect(colar.checkoutConversion == 3.0 / 7.0)
    }
}
