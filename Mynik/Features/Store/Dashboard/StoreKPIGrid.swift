import SwiftUI

/// Grelha com os KPIs principais do período.
struct StoreKPIGrid: View {
    let kpis: StoreKPIs

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        let current = kpis.current
        let previous = kpis.previous

        LazyVGrid(columns: columns, spacing: 10) {
            KPITile(
                title: "Vendas",
                value: Currency.format(current.sales),
                change: StoreKPIs.change(current.sales, previous.sales)
            )
            KPITile(
                title: "Lucro real",
                value: Currency.format(current.profit),
                change: StoreKPIs.change(current.profit, previous.profit)
            )
            KPITile(
                title: "Pedidos",
                value: current.orders.formatted(),
                change: StoreKPIs.change(Decimal(current.orders), Decimal(previous.orders))
            )
            KPITile(
                title: "Ticket médio",
                value: current.averageOrderValue.map { Currency.format($0) } ?? "—",
                change: StoreKPIs.change(current.averageOrderValue?.doubleValue, previous.averageOrderValue?.doubleValue)
            )
            KPITile(
                title: "Conversão",
                value: current.conversionRate.map { $0.formatted(.percent.precision(.fractionLength(1)).locale(.app)) } ?? "—",
                change: StoreKPIs.change(current.conversionRate, previous.conversionRate)
            )
            KPITile(
                title: "Margem",
                value: current.breakdown.margin.map { $0.formatted(.percent.precision(.fractionLength(0)).locale(.app)) } ?? "—",
                change: StoreKPIs.change(current.breakdown.margin, previous.breakdown.margin)
            )
        }
    }
}
