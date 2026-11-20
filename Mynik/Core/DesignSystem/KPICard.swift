import SwiftUI

/// Cartão com um número grande, a variação face ao período anterior e um mini gráfico opcional.
struct KPICard<Chart: View>: View {
    let title: String
    let value: String
    var symbolName: String?
    /// Variação relativa (0,1 = +10 %).
    var change: Double?
    /// Para custos, subir é mau.
    var higherIsBetter = true
    @ViewBuilder var chart: Chart
    @Environment(\.moduleTint) private var tint

    init(
        _ title: String,
        value: String,
        systemImage symbolName: String? = nil,
        change: Double? = nil,
        higherIsBetter: Bool = true,
        @ViewBuilder chart: () -> Chart = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.symbolName = symbolName
        self.change = change
        self.higherIsBetter = higherIsBetter
        self.chart = chart()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.subheadline)

            Text(value)
                .numberStyle(.kpi)

            HStack(alignment: .bottom) {
                ChangeBadge(change: change, higherIsBetter: higherIsBetter)
                Spacer(minLength: 0)
                chart
            }
        }
        .dsCard(padding: DS.Spacing.m + 2)
        .accessibilityElement(children: .combine)
    }
}

/// Variação percentual com seta, verde quando é boa e vermelha quando é má.
struct ChangeBadge: View {
    let change: Double?
    var higherIsBetter = true

    var body: some View {
        if let change {
            let isUp = change >= 0
            let isGood = isUp == higherIsBetter
            let color: Color = change == 0 ? .secondary : (isGood ? .green : .red)
            Label(
                change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()).locale(.app)),
                systemImage: isUp ? "arrow.up.right" : "arrow.down.right"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: .capsule)
            .accessibilityLabel("Variação \(change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()).locale(.app)))")
        } else {
            Text("sem comparação")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    HStack {
        KPICard("Vendas", value: "1 234 €", systemImage: "eurosign", change: 0.12) {
            Sparkline(values: [3, 5, 4, 8, 7, 9])
        }
        KPICard("Pedidos", value: "42", systemImage: "shippingbox", change: -0.05)
    }
    .padding()
    .background(Color.dsBackground)
}
