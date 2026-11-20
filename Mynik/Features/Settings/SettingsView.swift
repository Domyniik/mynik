import SwiftData
import SwiftUI

/// Definições da app.
struct SettingsView: View {
    var body: some View {
        Form {
            StoreSettingsSection()
            StoreCostSettingsSection()
            NotificationSettingsSection()
            CurrencySettingsSection()
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
