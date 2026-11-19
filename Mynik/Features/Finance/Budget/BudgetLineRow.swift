import SwiftUI

/// Linha de uma categoria no orçamento, com barra de progresso.
struct BudgetLineRow: View {
    let line: BudgetOverview.Line

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: line.category)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(line.category.name)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(amountText)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(line.isOverBudget ? .red : .secondary)
                }

                if line.hasBudget {
                    BudgetBar(progress: line.progress, tint: line.category.color.color)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(line.isOverBudget ? .red : .secondary)
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        line.hasBudget
            ? "\(Currency.format(line.spent)) / \(Currency.format(line.budget))"
            : Currency.format(line.spent)
    }

    private var statusText: String {
        line.isOverBudget
            ? "Passaste \(Currency.format(-line.remaining))"
            : "Faltam \(Currency.format(line.remaining))"
    }
}

/// Barra de progresso que fica vermelha quando passa dos 100%.
struct BudgetBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ProgressView(value: min(progress, 1))
            .tint(progress > 1 ? .red : (progress > 0.85 ? .orange : tint))
            .accessibilityValue("\(Int((progress * 100).rounded())) por cento")
    }
}
