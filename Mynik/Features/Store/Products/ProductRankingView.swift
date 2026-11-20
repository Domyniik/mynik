import SwiftData
import SwiftUI

/// Ranking dos produtos ativos, do melhor para o pior.
struct ProductRankingView: View {
    @Query private var products: [StoreProduct]
    @Query private var orders: [StoreOrder]
    @Query private var checkouts: [StoreCheckout]

    @State private var filter: ProductClass?

    private var ranking: [(performance: ProductPerformance, score: ProductScore)] {
        ProductScorer.rank(ProductPerformance.build(
            products: products,
            orders: orders,
            abandonedUnitsByProduct: StoreOperations.abandonedUnitsByProduct(checkouts)
        ))
    }

    var body: some View {
        let ranking = ranking
        let visible = ranking.filter { filter == nil || $0.score.classification == filter }

        List {
            Section {
                Picker("Classificação", selection: $filter) {
                    Text("Todos").tag(ProductClass?.none)
                    ForEach(ProductClass.allCases) { productClass in
                        let count = ranking.count { $0.score.classification == productClass }
                        Text("\(productClass.emoji) \(count)").tag(Optional(productClass))
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Score de 0 a 100 com vendas, receita, margem, funil, reembolsos, recência e ROAS dos últimos 30 dias.")
            }

            Section {
                if visible.isEmpty {
                    Text("Nenhum produto nesta classificação.")
                        .foregroundStyle(.secondary)
                }
                ForEach(visible, id: \.performance.id) { entry in
                    if let product = products.first(where: { $0.shopifyID == entry.performance.productID }) {
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRankRow(performance: entry.performance, score: entry.score)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ranking de produtos")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ProductRankingView()
    }
}
