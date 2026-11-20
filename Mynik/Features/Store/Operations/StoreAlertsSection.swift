import SwiftUI

/// Alertas da loja (dias sem venda, atrasos, stock) no topo do ecrã.
struct StoreAlertsSection: View {
    let products: [StoreProduct]
    let orders: [StoreOrder]

    @AppStorage(SettingsKey.storeNoSaleDays) private var noSaleDays = StoreAlerts.defaultNoSaleDays

    var body: some View {
        let alerts = StoreAlerts.make(products: products, orders: orders, noSaleDays: noSaleDays)

        if !alerts.isEmpty {
            Section("Alertas") {
                ForEach(alerts) { alert in
                    StoreAlertRow(alert: alert)
                }
            }
        }
    }
}

struct StoreAlertRow: View {
    let alert: StoreAlert

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title).font(.headline)
                Text(alert.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: alert.symbolName)
                .foregroundStyle(alert.isCritical ? .red : .orange)
        }
        .accessibilityElement(children: .combine)
    }
}
