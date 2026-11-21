import SwiftUI

/// Notificações da loja: novas vendas e dias sem vender.
struct StoreAlertSettingsSection: View {
    @AppStorage(SettingsKey.storeSaleNotifications) private var saleNotifications = true
    @AppStorage(SettingsKey.storeNoSaleDays) private var noSaleDays = StoreAlerts.defaultNoSaleDays

    var body: some View {
        Section {
            Toggle("Avisar de cada venda", isOn: $saleNotifications)
                .onChange(of: saleNotifications) {
                    if saleNotifications {
                        Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
                    }
                }
            Stepper(value: $noSaleDays, in: 1...14) {
                LabeledContent("Alerta sem vendas", value: noSaleDays == 1 ? "1 dia" : "\(noSaleDays) dias")
            }
        } header: {
            ListSectionHeader("Alertas da loja", systemImage: "exclamationmark.triangle", color: .orange)
        } footer: {
            Text("As vendas são verificadas ao abrir a app e em segundo plano no iPhone (quando o sistema deixa), ou de 15 em 15 minutos com a app aberta no Mac.")
        }
    }
}
