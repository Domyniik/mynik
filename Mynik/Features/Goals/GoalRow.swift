import SwiftUI

/// Linha de uma meta com barra de progresso.
struct GoalRow: View {
    let goal: Goal

    @Environment(\.currencyConverter) private var converter

    var body: some View {
        let progress = GoalProgress(goal: goal, converter: converter)
        HStack(spacing: 12) {
            SymbolBadge(symbolName: progress.isReached ? "checkmark" : goal.symbolName, color: goal.color.color)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(goal.title)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress.fraction)
                    .tint(goal.color.color)
                Text(subtitle(progress))
                    .font(.caption)
                    .foregroundStyle(progress.isPastDeadline && !progress.isReached ? .red : .secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ progress: GoalProgress) -> String {
        let amounts = "\(Currency.format(progress.current, code: goal.currencyCode)) de \(Currency.format(progress.target, code: goal.currencyCode))"
        if progress.isReached { return "\(amounts) · Meta atingida 🎉" }
        if progress.isPastDeadline { return "\(amounts) · Prazo passado" }
        if let monthly = progress.monthlyNeeded {
            return "\(amounts) · \(Currency.format(monthly, code: goal.currencyCode))/mês"
        }
        return amounts
    }
}
