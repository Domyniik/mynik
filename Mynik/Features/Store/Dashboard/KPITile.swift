import SwiftUI

/// Um KPI da loja: número grande, variação face ao período anterior e tendência opcional.
struct KPITile: View {
    let title: String
    var symbolName: String?
    let value: String
    /// Variação relativa (0,1 = +10 %).
    var change: Double?
    /// Para custos, subir é mau.
    var higherIsBetter = true
    /// Valores diários para o mini gráfico.
    var trend: [Double] = []

    var body: some View {
        KPICard(title, value: value, systemImage: symbolName, change: change, higherIsBetter: higherIsBetter) {
            if trend.count > 1 {
                Sparkline(values: trend, height: 26)
            }
        }
    }
}

#Preview {
    HStack {
        KPITile(title: "Vendas", symbolName: "eurosign", value: "1 234 €", change: 0.12, trend: [1, 3, 2, 5, 4])
        KPITile(title: "Pedidos", symbolName: "shippingbox", value: "42", change: -0.05)
    }
    .padding()
}
