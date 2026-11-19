import SwiftData
import SwiftUI

/// Definições da app.
struct SettingsView: View {
    var body: some View {
        Form {
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
