import SwiftData
import SwiftUI

/// Ecrã principal da loja Shopify: KPIs, lucro real e gráfico diário.
struct StoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSyncCoordinator.self) private var storeSync

    @Query(sort: \StoreOrder.createdAt, order: .reverse) private var orders: [StoreOrder]
    @Query(sort: \StoreProduct.title) private var products: [StoreProduct]
    @Query(sort: \DailyStat.date) private var stats: [DailyStat]
    @Query private var checkouts: [StoreCheckout]

    @AppStorage(SettingsKey.storeFeePercent) private var feePercent = StoreCostSettings.defaultFeePercent
    @AppStorage(SettingsKey.storeFeeFixed) private var feeFixed = StoreCostSettings.defaultFeeFixed
    @AppStorage(SettingsKey.storeShippingCost) private var shippingCost = StoreCostSettings.defaultShippingCost
    @AppStorage(SettingsKey.storeMonthlyAds) private var monthlyAds = 0.0

    @State private var period: StorePeriod = .week

    private var metrics: StoreMetrics {
        StoreMetrics(
            orders: orders,
            stats: stats,
            products: products,
            costs: StoreCostSettings(
                paymentFeePercent: feePercent,
                paymentFeeFixed: feeFixed,
                shippingCostPerOrder: shippingCost,
                monthlyAdSpend: monthlyAds
            )
        )
    }

    var body: some View {
        let metrics = metrics
        let kpis = metrics.kpis(for: period)

        List {
            StoreSyncBanner()

            StoreAlertsSection(products: products, orders: orders)

            Section {
                Picker("Período", selection: $period) {
                    ForEach(StorePeriod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                StoreKPIGrid(kpis: kpis)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12))
            } header: {
                Text("Resumo")
            } footer: {
                Text("Variação \(period.comparisonTitle).")
            }

            StoreOperationsSection(orders: orders, checkouts: checkouts)

            StoreRankingSummary(products: products, orders: orders, checkouts: checkouts)

            Section("Funil") {
                let funnel = FunnelDiagnosis.diagnose(stats: stats, days: 30)
                NavigationLink {
                    FunnelView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(funnel.problem.title, systemImage: funnel.problem.symbolName)
                            .font(.headline)
                        if let conversion = funnel.conversionRate {
                            Text("Conversão de \(conversion.formatted(.percent.precision(.fractionLength(1)).locale(.app))) nos últimos 30 dias")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Últimos 30 dias") {
                StoreDailyChart(points: metrics.dailyPoints(days: 30))
                    .padding(.vertical, 6)
            }

            ProfitBreakdownSection(
                breakdown: kpis.current.breakdown,
                periodTitle: period.title,
                missingCostCount: metrics.productsMissingCost.count
            )

            Section("Últimos pedidos") {
                if orders.isEmpty {
                    Text("Ainda não há pedidos.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orders.prefix(5)) { order in
                        StoreOrderRow(order: order)
                    }
                }
            }
        }
        .navigationTitle("Loja")
        .refreshable {
            await storeSync.refresh(in: modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Atualizar", systemImage: "arrow.clockwise") {
                    Task { await storeSync.refresh(in: modelContext) }
                }
                .disabled(storeSync.isSyncing)
            }
        }
        .task {
            await storeSync.refreshIfStale(in: modelContext)
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        StoreView()
    }
}
