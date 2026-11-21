import SwiftUI

/// Grelha com os KPIs principais do período.
struct StoreKPIGrid: View {
    let kpis: StoreKPIs
    /// Pontos diários para as tendências das vendas e do lucro.
    var points: [StoreDailyPoint] = []

    @ScaledMetric(relativeTo: .body) private var minimumWidth: CGFloat = 150
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: minimumWidth), spacing: DS.Spacing.s)] }

    var body: some View {
        let current = kpis.current
        let previous = kpis.previous

        LazyVGrid(columns: columns, spacing: DS.Spacing.s) {
            KPITile(
                title: "Vendas",
                symbolName: "eurosign.circle",
                value: Currency.format(current.sales),
                change: StoreKPIs.change(current.sales, previous.sales),
                trend: points.map { $0.sales.doubleValue }
            )
            KPITile(
                title: "Lucro real",
                symbolName: "banknote",
                value: Currency.format(current.profit),
                change: StoreKPIs.change(current.profit, previous.profit),
                trend: points.map { $0.profit.doubleValue }
            )
            KPITile(
                title: "Pedidos",
                symbolName: "shippingbox",
                value: current.orders.formatted(),
                change: StoreKPIs.change(Decimal(current.orders), Decimal(previous.orders))
            )
            KPITile(
                title: "Ticket médio",
                symbolName: "cart",
                value: current.averageOrderValue.map { Currency.format($0) } ?? "—",
                change: StoreKPIs.change(current.averageOrderValue?.doubleValue, previous.averageOrderValue?.doubleValue)
            )
            KPITile(
                title: "Conversão",
                symbolName: "arrow.triangle.turn.up.right.diamond",
                value: current.conversionRate.map { $0.formatted(.percent.precision(.fractionLength(1)).locale(.app)) } ?? "—",
                change: StoreKPIs.change(current.conversionRate, previous.conversionRate)
            )
            KPITile(
                title: "Margem",
                symbolName: "percent",
                value: current.breakdown.margin.map { $0.formatted(.percent.precision(.fractionLength(0)).locale(.app)) } ?? "—",
                change: StoreKPIs.change(current.breakdown.margin, previous.breakdown.margin)
            )
        }
    }
}
