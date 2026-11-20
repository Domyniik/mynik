import SwiftData
import SwiftUI

/// Checkouts abandonados dos últimos 30 dias, com o link de recuperação.
struct AbandonedCheckoutsView: View {
    @Query private var checkouts: [StoreCheckout]

    var body: some View {
        let recent = StoreOperations.recentCheckouts(checkouts)
        let total = recent.reduce(Decimal(0)) { $0 + $1.total }

        List {
            if recent.isEmpty {
                ContentUnavailableView("Sem carrinhos abandonados", systemImage: "cart", description: Text("Nos últimos 30 dias ninguém deixou um checkout a meio."))
            } else {
                Section {
                    LabeledContent("Valor em carrinhos", value: Currency.format(total))
                    LabeledContent("Checkouts", value: recent.count.formatted())
                } footer: {
                    Text("Envia o link de recuperação ao cliente (ou ativa os e-mails automáticos da Shopify) para retomar a compra.")
                }

                Section("Últimos 30 dias") {
                    ForEach(recent) { checkout in
                        AbandonedCheckoutRow(checkout: checkout)
                    }
                }
            }
        }
        .navigationTitle("Carrinhos abandonados")
    }
}

private struct AbandonedCheckoutRow: View {
    let checkout: StoreCheckout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(checkout.lines.map(\.title).joined(separator: ", "))
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(Currency.format(checkout.total))
                    .monospacedDigit()
            }
            Text(checkout.createdAt, format: .relative(presentation: .named).locale(.app))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = checkout.recoveryURL {
                ShareLink(item: url) {
                    Label("Partilhar link de recuperação", systemImage: "square.and.arrow.up")
                        .font(.callout)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        AbandonedCheckoutsView()
    }
}
