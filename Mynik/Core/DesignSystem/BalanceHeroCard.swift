import SwiftUI

/// Cartão principal com o saldo do mês sobre o gradiente da marca e a curva dos gastos.
struct BalanceHeroCard: View {
    let summary: MonthSummary
    /// Gastos acumulados por dia (para o mini gráfico).
    var trend: [Double] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let figures = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.s))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.s))

        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Saldo de \(Date.now.formatted(.dateTime.month(.wide).locale(.app)))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(Currency.format(summary.balance))
                        .numberStyle(.display)
                        .foregroundStyle(.white)
                        .animation(.snappy, value: summary.balance)
                }
                Spacer(minLength: DS.Spacing.s)
                if trend.count > 1, !dynamicTypeSize.isAccessibilitySize {
                    Sparkline(values: trend, color: .white, height: 40)
                        .padding(.top, DS.Spacing.xs)
                }
            }

            figures {
                HeroFigure(title: "Receitas", amount: summary.income, symbolName: "arrow.down.left")
                HeroFigure(title: "Gastos", amount: summary.expenses, symbolName: "arrow.up.right")
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(.brandGradient)
                .overlay(alignment: .topTrailing) {
                    // Brilho suave no canto, para dar profundidade.
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 220)
                        .blur(radius: 40)
                        .offset(x: 60, y: -90)
                }
                .clipShape(.rect(cornerRadius: DS.Radius.card))
                .shadow(color: .brandGradientBottom.opacity(0.3), radius: 16, y: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HeroFigure: View {
    let title: String
    let amount: Decimal
    let symbolName: String

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: symbolName)
                .font(.footnote.weight(.bold))
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.2), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(Currency.format(amount))
                    .numberStyle(.figure)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: .rect(cornerRadius: DS.Radius.tile))
    }
}

#Preview {
    BalanceHeroCard(summary: MonthSummary(income: 1850, expenses: 420), trend: [0, 50, 80, 300, 320, 420])
        .padding()
}
