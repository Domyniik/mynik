import SwiftData
import SwiftUI

/// Ecrã principal da loja Shopify.
struct StoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSyncCoordinator.self) private var storeSync

    @Query(sort: \StoreOrder.createdAt, order: .reverse) private var orders: [StoreOrder]
    @Query(sort: \StoreProduct.title) private var products: [StoreProduct]

    var body: some View {
        List {
            StoreSyncBanner()

            Section("Últimos pedidos") {
                if orders.isEmpty {
                    Text("Ainda não há pedidos.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orders.prefix(8)) { order in
                        StoreOrderRow(order: order)
                    }
                }
            }

            Section("Produtos (\(products.count))") {
                ForEach(products) { product in
                    LabeledContent(product.title) {
                        Text(Currency.format(product.price))
                    }
                }
            }
        }
        .navigationTitle("Loja")
        .refreshable {
            await storeSync.refresh(in: modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Atualizar", systemImage: "arrow.clockwise") {
                    Task { await storeSync.refresh(in: modelContext) }
                }
                .disabled(storeSync.isSyncing)
            }
        }
        .task {
            await storeSync.refreshIfStale(in: modelContext)
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        StoreView()
    }
}
