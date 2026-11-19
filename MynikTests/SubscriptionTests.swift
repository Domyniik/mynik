import Foundation
import Testing
@testable import Mynik

@MainActor
struct SubscriptionTests {
    @Test func normalisesCostsToMonthlyAndYearlyInEUR() {
        let bills = [
            Bill(title: "Spotify", amount: 10, dueDate: .now, recurrence: .monthly, isSubscription: true),
            Bill(title: "Domínio", amount: 24, dueDate: .now, recurrence: .yearly, isSubscription: true),
            Bill(title: "Netflix BR", amount: 50, dueDate: .now, recurrence: .monthly, isSubscription: true, currencyCode: "BRL"),
            Bill(title: "Renda", amount: 750, dueDate: .now, recurrence: .monthly),
        ]

        let summary = SubscriptionSummary(bills: bills, converter: CurrencyConverter(brlPerEUR: 5))

        #expect(summary.monthlyTotal == 22) // 10 + 2 + 10
        #expect(summary.yearlyTotal == 264)
    }

    @Test func weeklyCostUsesFiftyTwoWeeks() {
        let bill = Bill(title: "Jornal", amount: 3, dueDate: .now, recurrence: .weekly, isSubscription: true)
        #expect(SubscriptionSummary.monthlyCost(of: bill) == 13) // 3 × 52 / 12
    }

    @Test func oneOffBillHasNoMonthlyCost() {
        let bill = Bill(title: "ITV", amount: 40, dueDate: .now)
        #expect(SubscriptionSummary.monthlyCost(of: bill) == 0)
    }
}
