import SwiftData
import SwiftUI

/// Definições da app.
struct SettingsView: View {
    var body: some View {
        Form {
            StoreSettingsSection()
            StoreCostSettingsSection()
            StoreAlertSettingsSection()
            NotificationSettingsSection()
            CurrencySettingsSection()
            BackupSettingsSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Definições")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        SettingsView()
    }
}
