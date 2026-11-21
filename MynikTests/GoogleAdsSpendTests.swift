import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct GoogleAdsSpendTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 10)) ?? .distantPast
    }

    @Test func extractsSheetIDFromURLOrRawID() {
        let id = "140gr-eVKWyUjviySiqzCps9-XXwhh5Izk7VkBHs6lFo"
        #expect(GoogleAdsSpendImporter.sheetID(from: "https://docs.google.com/spreadsheets/d/\(id)/edit?usp=sharing") == id)
        #expect(GoogleAdsSpendImporter.sheetID(from: "  \(id) ") == id)
        #expect(GoogleAdsSpendImporter.sheetID(from: "não é uma folha") == nil)
    }

    @Test func parsesQuotedCampaignsAndCommaDecimals() {
        let csv = #"""
        date,campaign,cost,currency,final_url
        2026-11-20,"Neloce, Apliques",12.5,EUR,https://neloce.com/products/aplique-doble?variant=1
        2026-11-20,"PMax ""Inverno""","3,25",EUR,
        """#
        let rows = GoogleAdsSpendImporter.parse(csv: csv)

        #expect(rows.count == 2)
        #expect(rows[0].campaign == "Neloce, Apliques")
        #expect(rows[0].cost == Decimal(string: "12.5"))
        #expect(rows[1].campaign == "PMax \"Inverno\"")
        #expect(rows[1].cost == Decimal(string: "3.25"))
    }

    @Test func extractsProductHandleFromFinalURL() {
        #expect(GoogleAdsSpendImporter.productHandle(in: "https://neloce.com/products/Aplique-Doble?variant=1") == "aplique-doble")
        #expect(GoogleAdsSpendImporter.productHandle(in: "https://neloce.com/collections/all") == nil)
        #expect(GoogleAdsSpendImporter.productHandle(in: "") == nil)
    }

    @Test func summarizesLast30DaysByProduct() {
        let rows = [
            GoogleAdsSpendImporter.Row(date: "2026-11-21", campaign: "A", cost: 10, currency: "EUR", finalURL: "https://neloce.com/products/aplique"),
            GoogleAdsSpendImporter.Row(date: "2026-10-23", campaign: "A", cost: 5, currency: "EUR", finalURL: "https://neloce.com/products/aplique"),
            GoogleAdsSpendImporter.Row(date: "2026-10-22", campaign: "A", cost: 99, currency: "EUR", finalURL: "https://neloce.com/products/aplique"),
            GoogleAdsSpendImporter.Row(date: "2026-11-01", campaign: "PMax", cost: 20, currency: "EUR", finalURL: ""),
            GoogleAdsSpendImporter.Row(date: "2026-11-02", campaign: "BR", cost: 50, currency: "BRL", finalURL: ""),
        ]
        let summary = GoogleAdsSpendImporter.summarize(rows, now: now, calendar: calendar, converter: CurrencyConverter(brlPerEUR: 5))

        #expect(summary.perProductHandle["aplique"] == 15) // 22/10 fica fora dos 30 dias
        #expect(summary.unattributed == 30) // 20 EUR + 50 BRL (= 10 EUR)
        #expect(summary.total == 45)
    }

    @Test func applyWritesProductSpendAndGeneralAds() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let product = StoreProduct(shopifyID: "gid://shopify/Product/1", title: "Aplique")
        product.handle = "aplique"
        product.adSpend30d = 99
        let other = StoreProduct(shopifyID: "gid://shopify/Product/2", title: "Colar")
        other.handle = "colar"
        other.adSpend30d = 7
        context.insert(product)
        context.insert(other)
        let defaults = try #require(UserDefaults(suiteName: "GoogleAdsSpendTests"))
        defaults.removePersistentDomain(forName: "GoogleAdsSpendTests")

        let summary = GoogleAdsSpendImporter.Summary(perProductHandle: ["aplique": 15], unattributed: 30)
        try GoogleAdsSpendImporter.apply(summary, to: context, defaults: defaults, now: now)

        #expect(product.adSpend30d == 15)
        #expect(other.adSpend30d == 0)
        #expect(StoreCostSettings(defaults: defaults).monthlyAds == 30)
    }
}
