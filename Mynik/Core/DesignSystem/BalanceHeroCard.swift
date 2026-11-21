import SwiftUI

/// Um número secundário dentro do cartão de destaque.
struct HeroFigureItem: Identifiable {
    let title: String
    let value: String
    let symbolName: String
    var id: String { title }
}

/// Cartão de destaque: número principal sobre um gradiente, com mini gráfico e números secundários.
struct HeroCard: View {
    let title: String
    let value: String
    var figures: [HeroFigureItem] = []
    var trend: [Double] = []
    var colors: [Color] = [.brandGradientTop, .brandGradientBottom]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize || figures.count > 2
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.s))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.s))

        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(value)
                        .numberStyle(.display)
                        .foregroundStyle(.white)
                        .animation(.snappy, value: value)
                }
                Spacer(minLength: DS.Spacing.s)
                if trend.count > 1, !dynamicTypeSize.isAccessibilitySize {
                    Sparkline(values: trend, color: .white, height: 40)
                        .padding(.top, DS.Spacing.xs)
                }
            }

            if !figures.isEmpty {
                layout {
                    ForEach(figures) { HeroFigure(item: $0) }
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    // Brilho suave no canto, para dar profundidade.
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 220)
                        .blur(radius: 40)
                        .offset(x: 60, y: -90)
                }
                .clipShape(.rect(cornerRadius: DS.Radius.card))
                .shadow(color: (colors.last ?? .black).opacity(0.3), radius: 16, y: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HeroFigure: View {
    let item: HeroFigureItem

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: item.symbolName)
                .font(.footnote.weight(.bold))
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.2), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(item.value)
                    .numberStyle(.figure)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: .rect(cornerRadius: DS.Radius.tile))
    }
}

/// Cartão principal com o saldo do mês sobre o gradiente da marca e a curva dos gastos.
struct BalanceHeroCard: View {
    let summary: MonthSummary
    /// Gastos acumulados por dia (para o mini gráfico).
    var trend: [Double] = []

    var body: some View {
        HeroCard(
            title: "Saldo de \(Date.now.formatted(.dateTime.month(.wide).locale(.app)))",
            value: Currency.format(summary.balance),
            figures: [
                HeroFigureItem(title: "Receitas", value: Currency.format(summary.income), symbolName: "arrow.down.left"),
                HeroFigureItem(title: "Gastos", value: Currency.format(summary.expenses), symbolName: "arrow.up.right"),
            ],
            trend: trend
        )
    }
}

#Preview {
    BalanceHeroCard(summary: MonthSummary(income: 1850, expenses: 420), trend: [0, 50, 80, 300, 320, 420])
        .padding()
}
