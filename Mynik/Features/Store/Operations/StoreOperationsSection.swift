import SwiftUI

/// Atalhos para o dia a dia: pedidos por enviar e carrinhos abandonados.
struct StoreOperationsSection: View {
    let orders: [StoreOrder]
    let checkouts: [StoreCheckout]

    var body: some View {
        let pending = StoreOperations.ordersToShip(orders)
        let late = pending.count(where: \.isLate)
        let abandoned = StoreOperations.recentCheckouts(checkouts, days: 7)
        let abandonedValue = abandoned.reduce(Decimal(0)) { $0 + $1.total }

        Section("Para tratar") {
            NavigationLink {
                OrdersToShipView()
            } label: {
                LabeledContent {
                    Text(pending.count.formatted())
                        .monospacedDigit()
                        .foregroundStyle(late > 0 ? .red : .secondary)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pedidos por enviar")
                            if late > 0 {
                                Text("\(late) atrasado(s) há mais de \(StoreOperations.lateAfterDays) dias")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    } icon: {
                        Image(systemName: "shippingbox")
                    }
                }
            }

            NavigationLink {
                AbandonedCheckoutsView()
            } label: {
                LabeledContent {
                    Text(abandoned.count.formatted())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Carrinhos abandonados")
                            if abandonedValue > 0 {
                                Text("\(Currency.format(abandonedValue)) nos últimos 7 dias")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "cart.badge.questionmark")
                    }
                }
            }
        }
    }
}
