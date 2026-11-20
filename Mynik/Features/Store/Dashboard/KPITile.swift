import SwiftUI

/// Um número grande com a variação face ao período anterior.
struct KPITile: View {
    let title: String
    let value: String
    /// Variação relativa (0,1 = +10 %).
    var change: Double?
    /// Para custos, subir é mau.
    var higherIsBetter = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            changeLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.quaternary, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var changeLabel: some View {
        if let change {
            let isUp = change >= 0
            let isGood = isUp == higherIsBetter
            Label(
                change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()).locale(.app)),
                systemImage: isUp ? "arrow.up.right" : "arrow.down.right"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(change == 0 ? .secondary : (isGood ? Color.green : Color.red))
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    HStack {
        KPITile(title: "Vendas", value: "1 234 €", change: 0.12)
        KPITile(title: "Pedidos", value: "42", change: -0.05)
    }
    .padding()
}
