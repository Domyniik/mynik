import SwiftUI

/// Resumo do ranking no ecrã da loja: contagem por classificação e o melhor produto.
struct StoreRankingSummary: View {
    let products: [StoreProduct]
    let orders: [StoreOrder]
    let checkouts: [StoreCheckout]

    var body: some View {
        let ranking = ProductScorer.rank(ProductPerformance.build(
            products: products,
            orders: orders,
            abandonedUnitsByProduct: StoreOperations.abandonedUnitsByProduct(checkouts)
        ))

        Section("Produtos") {
            NavigationLink {
                ProductRankingView()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ranking de produtos").font(.headline)
                    HStack(spacing: 14) {
                        ForEach(ProductClass.allCases) { productClass in
                            let count = ranking.count { $0.score.classification == productClass }
                            Text("\(productClass.emoji) \(count)")
                                .monospacedDigit()
                                .accessibilityLabel("\(count) \(productClass.title)")
                        }
                    }
                    .font(.callout)
                    if let top = ranking.first {
                        Text("Melhor: \(top.performance.title) (\(top.score.score))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
