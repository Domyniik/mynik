import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct ProductLifecycleTests {
    @Test func newProductIsTestingWithDaysLeft() {
        #expect(ProductLifecycle.phase(ageDays: 5, decision: nil, classification: .winner) == .testing(daysLeft: 9))
    }

    @Test(arguments: [
        (ProductClass.winner, ProductDecision?.some(.scale)),
        (.promising, .some(.keep)),
        (.loser, .some(.discontinue)),
        (.testing, nil),
    ])
    func endedTestSuggestsDecisionFromRanking(classification: ProductClass, suggested: ProductDecision?) {
        #expect(ProductLifecycle.phase(ageDays: 20, decision: nil, classification: classification) == .awaitingDecision(suggested: suggested))
    }

    @Test func decisionWinsOverAgeAndClassification() {
        #expect(ProductLifecycle.phase(ageDays: 3, decision: .keep, classification: .loser) == .decided(.keep))
    }

    @Test func warnsWhenNumbersContradictDecision() {
        #expect(ProductLifecycle.reviewWarning(decision: .scale, classification: .loser, isActiveInShop: true) != nil)
        #expect(ProductLifecycle.reviewWarning(decision: .discontinue, classification: .loser, isActiveInShop: true)?.contains("Shopify") == true)
        #expect(ProductLifecycle.reviewWarning(decision: .discontinue, classification: .loser, isActiveInShop: false) == nil)
        #expect(ProductLifecycle.reviewWarning(decision: .scale, classification: .winner, isActiveInShop: true) == nil)
        #expect(ProductLifecycle.reviewWarning(decision: nil, classification: .loser, isActiveInShop: true) == nil)
    }

    @Test func decisionIsStoredAndSurvivesSync() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let since = Date.now.addingTimeInterval(-59 * 86_400)
        let record = StoreSnapshot.ProductRecord(id: "p1", title: "Colar", handle: "", status: "ACTIVE", imageURL: "",
                                                 price: 20, unitCost: 5, inventory: 3, tracksInventory: true, createdAt: since)
        let snapshot = StoreSnapshot(shopName: "T", products: [record], orders: [], traffic: [], trafficUnavailableReason: nil)

        try StoreCacheWriter.apply(snapshot, since: since, to: context)
        let product = try #require(try context.fetch(FetchDescriptor<StoreProduct>()).first)
        product.decision = .scale
        product.decisionNote = "Duplicar anúncios"
        #expect(product.decidedAt != nil)

        try StoreCacheWriter.apply(snapshot, since: since, to: context)
        #expect(product.decision == .scale)
        #expect(product.decisionNote == "Duplicar anúncios")

        product.decision = nil
        #expect(product.decisionRaw.isEmpty)
        #expect(product.decidedAt == nil)
    }
}
