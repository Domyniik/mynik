import SwiftData
import SwiftUI

/// Vendas da loja hoje, os últimos 7 dias e o alerta mais importante, na tela Hoje.
struct TodayStoreSection: View {
    @Query private var orders: [StoreOrder]
    @Query private var products: [StoreProduct]
    @Environment(AppRouter.self) private var router

    @AppStorage(SettingsKey.storeNoSaleDays) private var noSaleDays = StoreAlerts.defaultNoSaleDays

    var body: some View {
        if !orders.isEmpty {
            let metrics = StoreMetrics(orders: orders, stats: [], products: products, costs: StoreCostSettings())
            let today = metrics.values(in: StorePeriod.today.interval(endingAt: .now, calendar: .current))
            let week = metrics.dailyPoints(days: 7).map { NSDecimalNumber(decimal: $0.sales).doubleValue }
            let alert = StoreAlerts.make(products: products, orders: orders, noSaleDays: noSaleDays).first

            DashboardCard("Loja", systemImage: "storefront") {
                Button("Abrir") { router.open(.store) }
                    .buttonStyle(.borderless)
            } content: {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(Currency.format(today.sales))
                            .numberStyle(.kpi)
                        Text(today.orders == 1 ? "1 venda hoje" : "\(today.orders) vendas hoje")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    MiniBars(values: week, height: 40)
                }
                .accessibilityElement(children: .combine)
                if let alert {
                    Divider()
                    StoreAlertRow(alert: alert)
                }
            }
            .environment(\.moduleTint, AppSection.store.tint)
        }
    }
}
