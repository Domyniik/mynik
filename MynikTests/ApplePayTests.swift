import Foundation
import SwiftData
import Testing
@testable import Mynik

struct AmountTextParserTests {
    @Test(arguments: [
        ("12,50 €", "12.5", "EUR"),
        ("€12.50", "12.5", "EUR"),
        ("1.234,56 €", "1234.56", "EUR"),
        ("1,234.56", "1234.56", "EUR"),
        ("R$ 10,00", "10", "BRL"),
        ("7", "7", "EUR"),
        ("3,5", "3.5", "EUR"),
        ("1.000 €", "1000", "EUR"),
    ])
    func parsesShortcutAmounts(text: String, amount: String, currency: String) {
        #expect(AmountTextParser.parse(text) == .init(amount: Decimal(string: amount)!, currencyCode: currency))
    }

    @Test func rejectsTextWithoutAmount() {
        #expect(AmountTextParser.parse("") == nil)
        #expect(AmountTextParser.parse("€") == nil)
        #expect(AmountTextParser.parse("0,00 €") == nil)
    }
}

@MainActor
struct ApplePayEntryTests {
    @Test func registersPurchaseReusingMerchantCategoryOnce() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try DefaultDataSeeder.seedIfNeeded(in: context)
        let leisure = try #require(QuickEntryService.category(matching: "Lazer", in: context))
        context.insert(FinanceTransaction(title: "Cinesa", amount: 8, kind: .expense, category: leisure))
        try context.save()

        let date = Date(timeIntervalSince1970: 1_795_000_020) // início de um minuto
        let first = try ApplePayEntry.register(merchant: "Cinesa", amountText: "9,90 €", card: "Revolut", date: date, in: context)
        #expect(!first.isDuplicate)
        #expect(first.transaction.amount == Decimal(string: "9.9"))
        #expect(first.transaction.category?.name == "Lazer")
        #expect(first.transaction.notes == "Apple Pay · Revolut")
        #expect(first.message == "Registei \(Currency.format(9.9)) em Cinesa · Lazer.")

        let again = try ApplePayEntry.register(merchant: "Cinesa", amountText: "9,90 €", card: nil, date: date.addingTimeInterval(20), in: context)
        #expect(again.isDuplicate)
        #expect(try context.fetchCount(FetchDescriptor<FinanceTransaction>()) == 2)
    }

    @Test func unknownMerchantGoesToOthers() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try DefaultDataSeeder.seedIfNeeded(in: context)
        let outcome = try ApplePayEntry.register(merchant: "Loja XPTO", amountText: "R$ 25,00", card: nil, in: context)
        #expect(outcome.transaction.category?.name == "Outros")
        #expect(outcome.transaction.currencyCode == "BRL")
        #expect(throws: QuickEntryError.self) {
            try ApplePayEntry.register(merchant: "X", amountText: "grátis", card: nil, in: context)
        }
    }
}
