import SwiftUI

/// Saldo do mês com receitas e gastos. Usado em Finanças e em Hoje.
struct MonthSummaryCard: View {
    let summary: MonthSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Nos tamanhos de acessibilidade, receitas e gastos ficam um por linha.
        let figures = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 24))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            figures {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    MonthSummaryCard(summary: MonthSummary(income: 1850, expenses: 420))
        .padding()
}
