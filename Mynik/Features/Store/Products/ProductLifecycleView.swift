import SwiftData
import SwiftUI

/// Quadro do ciclo de vida: decisões pendentes, em teste e já decididos.
struct ProductLifecycleView: View {
    @Query(sort: \StoreProduct.title) private var products: [StoreProduct]
    @Query private var orders: [StoreOrder]
    @Query private var checkouts: [StoreCheckout]

    private struct Entry: Identifiable {
        let product: StoreProduct
        let performance: ProductPerformance
        let score: ProductScore
        let phase: ProductLifecycle.Phase
        var id: String { product.shopifyID }
    }

    private var entries: [Entry] {
        let byID = Dictionary(products.map { ($0.shopifyID, $0) }, uniquingKeysWith: { first, _ in first })
        return ProductScorer.rank(ProductPerformance.build(
            products: products,
            orders: orders,
            abandonedUnitsByProduct: StoreOperations.abandonedUnitsByProduct(checkouts)
        ))
        .compactMap { entry in
            guard let product = byID[entry.performance.productID] else { return nil }
            let phase = ProductLifecycle.phase(
                ageDays: entry.performance.ageDays,
                decision: product.decision,
                classification: entry.score.classification
            )
            return Entry(product: product, performance: entry.performance, score: entry.score, phase: phase)
        }
    }

    var body: some View {
        let groups = Dictionary(grouping: entries) { $0.phase.sortOrder }

        List {
            if entries.isEmpty {
                ContentUnavailableView("Sem produtos ativos", systemImage: "shippingbox")
            }
            ForEach(groups.keys.sorted(), id: \.self) { key in
                if let items = groups[key], let first = items.first {
                    Section("\(first.phase.title) (\(items.count))") {
                        ForEach(items) { entry in
                            NavigationLink {
                                ProductDetailView(product: entry.product)
                            } label: {
                                row(entry)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Ciclo de vida")
    }

    private func row(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(entry.score.classification.emoji) \(entry.performance.title)")
                .font(.headline)
            Text(detail(entry))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func detail(_ entry: Entry) -> String {
        switch entry.phase {
        case .testing(let daysLeft):
            "Faltam \(daysLeft) dias · \(entry.performance.units) un. vendidas"
        case .awaitingDecision(let suggested):
            suggested.map { "Sugestão: \($0.title) · score \(entry.score.score)" } ?? "Poucos dados: prolongar o teste"
        case .decided:
            ProductLifecycle.reviewWarning(
                decision: entry.product.decision,
                classification: entry.score.classification,
                isActiveInShop: entry.product.isActive
            ) ?? "Score \(entry.score.score) · \(entry.performance.units) un. em 30 dias"
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ProductLifecycleView()
    }
}
