import SwiftUI

/// Das vendas ao lucro real, linha a linha.
struct ProfitBreakdownSection: View {
    let breakdown: ProfitBreakdown
    let periodTitle: String
    /// Produtos vendidos sem custo definido.
    var missingCostCount = 0

    var body: some View {
        Section {
            row("Vendas (com IVA)", breakdown.grossSales)
            row("IVA", -breakdown.vat)
            row("Custo dos artigos", -breakdown.productCosts)
            row("Envios", -breakdown.shippingCosts)
            row("Taxas de pagamento", -breakdown.paymentFees)
            row("Anúncios", -breakdown.adSpend)

            LabeledContent {
                Text(Currency.format(breakdown.profit))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(breakdown.profit >= 0 ? .green : .red)
            } label: {
                Text("Lucro real").fontWeight(.semibold)
            }

            if missingCostCount > 0 {
                Label(
                    "\(missingCostCount) produto(s) vendidos sem custo definido: o lucro está sobrestimado.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        } header: {
            Text("Lucro real · \(periodTitle)")
        } footer: {
            Text("Envios, taxas e anúncios gerais ajustam-se em Definições › Custos da loja.")
        }
    }

    private func row(_ title: String, _ amount: Decimal) -> some View {
        LabeledContent(title) {
            Text(Currency.format(amount))
                .monospacedDigit()
                .foregroundStyle(amount < 0 ? .secondary : .primary)
        }
    }
}
