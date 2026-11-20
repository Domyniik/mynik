import SwiftData
import SwiftUI

/// Pedidos pagos que ainda não foram enviados, do mais antigo para o mais recente.
struct OrdersToShipView: View {
    @Query private var orders: [StoreOrder]

    var body: some View {
        let pending = StoreOperations.ordersToShip(orders)

        List {
            if pending.isEmpty {
                ContentUnavailableView("Tudo enviado", systemImage: "shippingbox", description: Text("Não há pedidos à espera de envio."))
            } else {
                Section {
                    ForEach(pending) { item in
                        HStack(alignment: .top) {
                            StoreOrderRow(order: item.order)
                            WaitingBadge(days: item.daysWaiting, isLate: item.isLate)
                        }
                    }
                } footer: {
                    Text("Pedidos com mais de \(StoreOperations.lateAfterDays) dias à espera aparecem a vermelho. Os envios fazem-se no admin da Shopify.")
                }
            }
        }
        .navigationTitle("Por enviar")
    }
}

private struct WaitingBadge: View {
    let days: Int
    let isLate: Bool

    var body: some View {
        Text(days == 0 ? "Hoje" : "\(days) d")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((isLate ? Color.red : Color.secondary).opacity(0.15), in: .capsule)
            .foregroundStyle(isLate ? .red : .secondary)
            .accessibilityLabel(days == 0 ? "Pedido de hoje" : "À espera há \(days) dias")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        OrdersToShipView()
    }
}
