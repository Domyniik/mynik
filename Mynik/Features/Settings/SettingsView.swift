import SwiftData
import SwiftUI

/// Definições da app.
struct SettingsView: View {
    var body: some View {
        Form {
            AccountSettingsSection()
            AppLockSettingsSection()
            AISettingsSection()
            StoreSettingsSection()
            StoreCostSettingsSection()
            StoreAlertSettingsSection()
            NotificationSettingsSection()
            CalendarSettingsSection()
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
    .environment(AccountSync(config: nil))
}
