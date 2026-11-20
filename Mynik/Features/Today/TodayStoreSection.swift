import SwiftData
import SwiftUI

/// Vendas da loja hoje e o alerta mais importante, na tela Hoje.
struct TodayStoreSection: View {
    @Query private var orders: [StoreOrder]
    @Query private var products: [StoreProduct]

    @AppStorage(SettingsKey.storeNoSaleDays) private var noSaleDays = StoreAlerts.defaultNoSaleDays

    var body: some View {
        if !orders.isEmpty {
            let today = StoreMetrics(orders: orders, stats: [], products: products, costs: StoreCostSettings())
                .values(in: StorePeriod.today.interval(endingAt: .now, calendar: .current))
            let alert = StoreAlerts.make(products: products, orders: orders, noSaleDays: noSaleDays).first

            Section("Loja") {
                LabeledContent {
                    Text(Currency.format(today.sales))
                        .monospacedDigit()
                        .fontWeight(.semibold)
                } label: {
                    Label(today.orders == 1 ? "1 venda hoje" : "\(today.orders) vendas hoje", systemImage: "storefront")
                }
                if let alert {
                    StoreAlertRow(alert: alert)
                }
            }
        }
    }
}
