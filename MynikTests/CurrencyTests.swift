import Foundation
import Testing
@testable import Mynik

@MainActor
struct CurrencyTests {
    @Test func convertsBetweenEURAndBRL() {
        let converter = CurrencyConverter(brlPerEUR: 6.5)
        #expect(converter.convert(10, from: "EUR", to: "BRL") == 65)
        #expect(converter.convert(65, from: "BRL", to: "EUR") == 10)
        #expect(converter.convert(42, from: "EUR") == 42)
    }

    @Test func invalidRateFallsBackToDefault() {
        let converter = CurrencyConverter(brlPerEUR: 0)
        #expect(converter.brlPerEUR > 0)
    }

    @Test func transactionInBRLIsConvertedToEUR() {
        let converter = CurrencyConverter(brlPerEUR: 5)
        let transaction = FinanceTransaction(title: "Pix", amount: 100, kind: .expense, currencyCode: "BRL")
        #expect(converter.amountInDefaultCurrency(transaction) == 20)
    }

    @Test func decodesFrankfurterResponse() throws {
        let json = Data(#"{"amount":1.0,"base":"EUR","date":"2026-11-19","rates":{"BRL":6.4765}}"#.utf8)
        let rate = try ExchangeRateService.decode(json)
        #expect(rate.brlPerEUR == 6.4765)
        #expect(rate.date == "2026-11-19")
    }
}
