import SwiftUI

/// Inteligência: categorização automática e estado da Apple Intelligence.
struct AISettingsSection: View {
    @AppStorage(SettingsKey.autoCategorize) private var autoCategorize = true
    @State private var status = AppleIntelligence.Status.unknown

    var body: some View {
        Section {
            Toggle("Sugerir categoria dos movimentos", isOn: $autoCategorize)
            LabeledContent("Apple Intelligence") {
                Label(status.isAvailable ? "Ativa" : "Indisponível",
                      systemImage: status.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(status.isAvailable ? .green : .secondary)
            }
        } header: {
            Text("Inteligência")
        } footer: {
            Text(status.message)
        }
        .task { status = AppleIntelligence.status }
    }
}
