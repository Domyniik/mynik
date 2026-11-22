import SwiftData
import SwiftUI

/// Ficha de um produto: score, fatores, números e custos editáveis.
struct ProductDetailView: View {
    @Bindable var product: StoreProduct

    @Query private var products: [StoreProduct]
    @Query private var orders: [StoreOrder]
    @Query private var checkouts: [StoreCheckout]

    private var entry: (performance: ProductPerformance, score: ProductScore)? {
        ProductScorer.rank(ProductPerformance.build(
            products: products,
            orders: orders,
            abandonedUnitsByProduct: StoreOperations.abandonedUnitsByProduct(checkouts)
        ))
            .first { $0.performance.productID == product.shopifyID }
    }

    var body: some View {
        Form {
            if let entry {
                summarySection(entry.performance, entry.score)
                ProductLifecycleSection(product: product, performance: entry.performance, score: entry.score)
                factorsSection(entry.score)
                numbersSection(entry.performance)
            } else {
                Section {
                    Text("Produto inativo: não entra no ranking.")
                        .foregroundStyle(.secondary)
                }
            }
            costsSection
        }
        .formStyle(.grouped)
        .navigationTitle(product.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summarySection(_ performance: ProductPerformance, _ score: ProductScore) -> some View {
        Section {
            HStack(spacing: 14) {
                ScoreBadge(score: score.score, classification: score.classification)
                    .scaleEffect(1.3)
                    .padding(6)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(score.classification.emoji) \(score.classification.title)")
                        .font(.headline)
                    Text(score.action)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func factorsSection(_ score: ProductScore) -> some View {
        Section("Fatores do score") {
            ForEach(score.factors) { factor in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(factor.name)
                        Spacer()
                        Text("\(Int(factor.points.rounded()))/\(Int(factor.maxPoints))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: factor.ratio)
                        .tint(factor.hasData ? tint(for: factor.ratio) : .gray)
                    Text(factor.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func numbersSection(_ performance: ProductPerformance) -> some View {
        Section("Últimos 30 dias") {
            LabeledContent("Unidades vendidas", value: performance.units.formatted())
            LabeledContent("Receita", value: Currency.format(performance.revenue))
            if performance.refundedUnits > 0 {
                LabeledContent("Devolvidas", value: performance.refundedUnits.formatted())
            }
            LabeledContent("Margem por unidade", value: Currency.format(product.unitMargin))
            if product.tracksInventory {
                LabeledContent("Stock", value: performance.daysOfStock.map { "\(product.inventory) (≈\($0) dias)" } ?? product.inventory.formatted())
            }
            LabeledContent("Na loja há", value: "\(performance.ageDays) dias")
        }
    }

    private var costsSection: some View {
        Section {
            LabeledContent("Preço", value: Currency.format(product.price))
            LabeledContent("Custo por unidade") {
                TextField("Custo", value: $product.unitCost, format: .currency(code: Currency.defaultCode).locale(.app))
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
                    .keyboardType(.decimalPad)
                    .onChange(of: product.unitCost) { product.unitCostIsManual = true }
            }
            if product.unitCostIsManual {
                Button("Voltar a usar o custo da Shopify", systemImage: "arrow.uturn.backward") {
                    product.unitCostIsManual = false
                }
                .font(.callout)
            }
            LabeledContent("Anúncios (30 dias)") {
                TextField("Anúncios", value: $product.adSpend30d, format: .currency(code: Currency.defaultCode).locale(.app))
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Custos")
        } footer: {
            Text("O custo vem do campo “Custo por artigo” da Shopify; se o alterares aqui, fica o teu valor. O gasto em anúncios serve para o ROAS e o lucro real.")
        }
    }

    private func tint(for ratio: Double) -> Color {
        switch ratio {
        case 0.7...: .green
        case 0.4..<0.7: .yellow
        default: .red
        }
    }
}
