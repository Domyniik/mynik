import SwiftUI

/// Linha de um pedido: número, artigos, data e total.
struct StoreOrderRow: View {
    let order: StoreOrder

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(order.name).font(.headline)
                Text(order.lines.map(\.title).joined(separator: ", "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(order.createdAt, format: .dateTime.day().month().hour().minute().locale(.app))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Currency.format(order.total, code: order.currencyCode))
                    .monospacedDigit()
                    .strikethrough(order.isCancelled)
                if order.refunded > 0 {
                    Text("Reembolso \(Currency.format(order.refunded, code: order.currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
