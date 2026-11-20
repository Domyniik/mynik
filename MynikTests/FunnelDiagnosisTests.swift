import Foundation
import Testing
@testable import Mynik

@MainActor
struct FunnelDiagnosisTests {
    private func diagnose(sessions: Int, cart: Int, checkout: Int, completed: Int, days: Int = 30, traffic: Bool = true) -> FunnelDiagnosis {
        FunnelDiagnosis.diagnose(
            .init(sessions: sessions, cart: cart, checkout: checkout, completed: completed, hasTraffic: traffic),
            days: days
        )
    }

    @Test func lowAddToCartPointsToPageOrPrice() {
        let diagnosis = diagnose(sessions: 3000, cart: 90, checkout: 60, completed: 40)
        #expect(diagnosis.problem == .pagePrice)
        #expect(diagnosis.stages[1].status == .weak)
        #expect(diagnosis.conversionRate == 40.0 / 3000.0)
    }

    @Test func dropBeforePaymentPointsToCheckoutOrShipping() {
        let cartToCheckout = diagnose(sessions: 3000, cart: 240, checkout: 60, completed: 40)
        #expect(cartToCheckout.problem == .checkoutShipping)

        let checkoutToPurchase = diagnose(sessions: 3000, cart: 240, checkout: 150, completed: 30)
        #expect(checkoutToPurchase.problem == .checkoutShipping)
        #expect(checkoutToPurchase.stages[3].status == .weak)
    }

    @Test func picksTheWorstStageWhenSeveralAreWeak() {
        // Carrinho 3,5 % (0,875 do limite) vs checkout 10 % (0,29 do limite).
        let diagnosis = diagnose(sessions: 4000, cart: 140, checkout: 14, completed: 10)
        #expect(diagnosis.problem == .checkoutShipping)
    }

    @Test func goodFunnelWithFewVisitsIsATrafficProblem() {
        let diagnosis = diagnose(sessions: 600, cart: 48, checkout: 30, completed: 18)
        #expect(diagnosis.sessionsPerDay == 20)
        #expect(diagnosis.problem == .traffic)

        let busy = diagnose(sessions: 3000, cart: 240, checkout: 150, completed: 90)
        #expect(busy.problem == .healthy)
    }

    @Test func needsTrafficAndEnoughVisits() {
        #expect(diagnose(sessions: 0, cart: 0, checkout: 0, completed: 0, traffic: false).problem == .noTrafficData)
        #expect(diagnose(sessions: 60, cart: 2, checkout: 1, completed: 1).problem == .notEnoughData)
    }

    @Test func demoStoreShowsCheckoutProblem() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 15)) ?? .now
        let since = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
        let snapshot = try await DemoStoreDataSource(now: now, calendar: calendar).fetchSnapshot(since: since)

        var totals = FunnelDiagnosis.DayTotals(hasTraffic: true)
        for day in snapshot.traffic {
            totals.sessions += day.sessions
            totals.cart += day.cartSessions
            totals.checkout += day.checkoutSessions
            totals.completed += day.completedSessions
        }
        #expect(FunnelDiagnosis.diagnose(totals, days: 30).problem == .checkoutShipping)
    }
}
