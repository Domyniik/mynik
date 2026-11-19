import SwiftData
import SwiftUI

/// Relatórios com gráficos: gastos por categoria e evolução mensal.
struct ReportsView: View {
    @Environment(\.currencyConverter) private var converter
    @Query private var transactions: [FinanceTransaction]

    @State private var month = Date.now

    var body: some View {
        let slices = FinanceReport.expensesByCategory(month: month, transactions: transactions, converter: converter)
        let totals = FinanceReport.monthlyTotals(endingAt: month, transactions: transactions, converter: converter)

        List {
            Section {
                MonthStepper(month: $month)
            }

            Section("Gastos por categoria") {
                if slices.isEmpty {
                    Text("Sem gastos neste mês.")
                        .foregroundStyle(.secondary)
                } else {
                    CategoryDonutChart(slices: slices)
                        .padding(.vertical, 8)
                    ForEach(slices) { slice in
                        CategorySliceRow(slice: slice, total: slices.reduce(0) { $0 + $1.amount })
                    }
                }
            }

            Section("Receitas e gastos · 6 meses") {
                MonthlyBarsChart(totals: totals)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Relatórios")
    }
}

private struct CategorySliceRow: View {
    let slice: FinanceReport.CategorySlice
    let total: Decimal

    private var share: Double {
        total > 0 ? NSDecimalNumber(decimal: slice.amount / total).doubleValue : 0
    }

    var body: some View {
        HStack {
            Circle()
                .fill(slice.color.color)
                .frame(width: 10, height: 10)
            Text(slice.name)
            Spacer()
            Text(share.formatted(.percent.precision(.fractionLength(0)).locale(.app)))
                .foregroundStyle(.secondary)
            Text(Currency.format(slice.amount))
                .monospacedDigit()
                .frame(minWidth: 90, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ReportsView()
    }
}
