import SwiftUI

/// Saldo do mês com receitas e gastos. Usado em Finanças e em Hoje.
struct MonthSummaryCard: View {
    let summary: MonthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo do mês")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(Currency.format(summary.balance))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(summary.balance < 0 ? .red : .primary)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 24) {
                SummaryFigure(title: "Receitas", amount: summary.income, symbolName: "arrow.down.left", tint: .green)
                SummaryFigure(title: "Gastos", amount: summary.expenses, symbolName: "arrow.up.right", tint: .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryFigure: View {
    let title: String
    let amount: Decimal
    let symbolName: String
    let tint: Color

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Currency.format(amount))
                    .font(.headline)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    MonthSummaryCard(summary: MonthSummary(income: 1850, expenses: 420))
        .padding()
}
