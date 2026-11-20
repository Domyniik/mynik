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

        let decisions = Dictionary(products.map { ($0.shopifyID, $0.decision) }, uniquingKeysWith: { first, _ in first })
        let pendingDecisions = ranking.count { entry in
            if case .awaitingDecision = ProductLifecycle.phase(
                ageDays: entry.performance.ageDays,
                decision: decisions[entry.performance.productID] ?? nil,
                classification: entry.score.classification
            ) { return true }
            return false
        }

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

            NavigationLink {
                ProductLifecycleView()
            } label: {
                LabeledContent {
                    if pendingDecisions > 0 {
                        Text(pendingDecisions.formatted())
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ciclo de vida")
                            Text(pendingDecisions == 0 ? "Sem decisões pendentes" : "\(pendingDecisions) decisão(ões) pendente(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
    }
}
