import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct StoreProfitPosterTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar(identifier: .gregorian)
    private let now: Date
    private let costs = StoreCostSettings(paymentFeePercent: 0, paymentFeeFixed: 0, shippingCostPerOrder: 0, monthlyAdSpend: 0)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
        now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15)) ?? .now
    }

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? now
    }

    /// Pedido de 24,60 € (IVA 4,60) de um produto com custo 5 → lucro 15.
    private func insertOrder(_ id: String, on day: Date) {
        context.insert(StoreOrder(
            shopifyID: id, name: "#\(id)", createdAt: day, subtotal: 24.6, tax: 4.6, total: 24.6,
            lines: [StoreOrderLine(productID: "p1", title: "Colar", quantity: 1, currentQuantity: 1, unitPrice: 24.6)]
        ))
    }

    private func storeTransactions() throws -> [FinanceTransaction] {
        try context.fetch(FetchDescriptor<FinanceTransaction>(sortBy: [SortDescriptor(\.date)]))
            .filter { $0.externalID.hasPrefix(StoreProfitPoster.externalIDPrefix) }
    }

    @Test func postsOneIncomePerMonthAndUpdatesInsteadOfDuplicating() throws {
        context.insert(StoreProduct(shopifyID: "p1", title: "Colar", price: 24.6, unitCost: 5))
        insertOrder("1", on: date(10, 5))
        insertOrder("2", on: date(11, 3))
        insertOrder("3", on: date(11, 15))
        let since = date(9, 22)

        try StoreProfitPoster.post(in: context, costs: costs, since: since, now: now, calendar: calendar)
        insertOrder("4", on: date(11, 20))
        try StoreProfitPoster.post(in: context, costs: costs, since: since, now: now, calendar: calendar)

        let transactions = try storeTransactions()
        #expect(transactions.count == 2)
        #expect(transactions.map(\.externalID) == ["store-profit-2026-10", "store-profit-2026-11"])
        #expect(transactions.map(\.amount) == [15, 45])
        #expect(transactions.allSatisfy { $0.kind == .income && $0.category?.name == "Loja" && $0.isAutomatic })
        #expect(transactions[1].title == "Lucro da loja · \(date(11, 1).formatted(.dateTime.month(.wide).year().locale(.app)))")
        #expect(transactions[1].date <= now)
    }

    @Test func lossBecomesExpenseWithoutStoreCategory() throws {
        context.insert(StoreProduct(shopifyID: "p1", title: "Colar", price: 24.6, unitCost: 30))
        insertOrder("1", on: date(11, 3))

        try StoreProfitPoster.post(in: context, costs: costs, since: date(9, 22), now: now, calendar: calendar)

        let transaction = try #require(try storeTransactions().first)
        #expect(transaction.kind == .expense)
        #expect(transaction.amount == 10)
        #expect(transaction.category == nil)
        #expect(transaction.title.hasPrefix("Prejuízo da loja"))
    }

    @Test func skipsMonthsNotFullyCoveredByCache() throws {
        context.insert(StoreProduct(shopifyID: "p1", title: "Colar", price: 24.6, unitCost: 5))
        insertOrder("1", on: date(10, 25))
        insertOrder("2", on: date(11, 3))

        // A cache só começa a 15 de outubro: outubro ficaria incompleto.
        try StoreProfitPoster.post(in: context, costs: costs, since: date(10, 15), now: now, calendar: calendar)

        #expect(try storeTransactions().map(\.externalID) == ["store-profit-2026-11"])
    }

    @Test func monthWithoutOrdersCreatesNothing() throws {
        try StoreProfitPoster.post(in: context, costs: costs, since: date(9, 22), now: now, calendar: calendar)
        #expect(try storeTransactions().isEmpty)
    }
}
