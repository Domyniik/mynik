import SwiftUI

/// Ecrã de destino de cada `FinanceRoute`.
struct FinanceRouteDestination: View {
    let route: FinanceRoute

    var body: some View {
        switch route {
        case .bills: BillsView()
        case .budget: BudgetView()
        case .reports: ReportsView()
        case .subscriptions: SubscriptionsView()
        }
    }
}
