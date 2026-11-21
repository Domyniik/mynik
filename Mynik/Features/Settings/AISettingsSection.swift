import SwiftUI

/// Inteligência: categorização automática e estado da Apple Intelligence.
struct AISettingsSection: View {
    @AppStorage(SettingsKey.autoCategorize) private var autoCategorize = true
    @State private var status = AppleIntelligence.Status.unknown

    var body: some View {
        Section {
            Toggle("Sugerir categoria dos movimentos", isOn: $autoCategorize)
            HStack {
                Text("Apple Intelligence")
                Spacer()
                Group {
                    Image(systemName: status.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                        .accessibilityHidden(true)
                    Text(status.isAvailable ? "Ativa" : "Indisponível")
                }
                .foregroundStyle(status.isAvailable ? .green : .secondary)
            }
            .accessibilityElement(children: .combine)
        } header: {
            ListSectionHeader("Inteligência", systemImage: "sparkles", color: .purple)
        } footer: {
            Text(status.message)
        }
        .task { status = AppleIntelligence.status }
    }
}
