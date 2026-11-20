import SwiftUI

/// Linha do ranking: classificação, nome, números principais e ação sugerida.
struct ProductRankRow: View {
    let performance: ProductPerformance
    let score: ProductScore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(score.classification.emoji)
                .font(.title2)
                .accessibilityLabel(score.classification.title)

            VStack(alignment: .leading, spacing: 3) {
                Text(performance.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(performance.units) un. · \(Currency.format(performance.revenue))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(score.action)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            ScoreBadge(score: score.score, classification: score.classification)
        }
        .padding(.vertical, 2)
    }
}

/// Score de 0 a 100 num círculo com a cor da classificação.
struct ScoreBadge: View {
    let score: Int
    let classification: ProductClass

    var body: some View {
        Text(score.formatted())
            .font(.callout.weight(.bold))
            .monospacedDigit()
            .frame(width: 40, height: 40)
            .background(classification.color.opacity(0.18), in: .circle)
            .foregroundStyle(classification.color)
            .accessibilityLabel("Score \(score) de 100")
    }
}

extension ProductClass {
    var color: Color {
        switch self {
        case .winner: .green
        case .promising: .yellow
        case .testing: .orange
        case .loser: .red
        }
    }
}
