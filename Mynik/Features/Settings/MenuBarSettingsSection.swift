#if os(macOS)
import SwiftUI

/// Mostrar ou esconder o Mynik na barra de menus do Mac.
struct MenuBarSettingsSection: View {
    @AppStorage(SettingsKey.showMenuBarExtra) private var showMenuBarExtra = true

    var body: some View {
        Section {
            Toggle("Mostrar na barra de menus", isOn: $showMenuBarExtra)
        } header: {
            ListSectionHeader("Barra de menus", systemImage: "menubar.rectangle", color: .gray)
        } footer: {
            Text("Saldo do mês, contas a vencer e um gasto rápido sem abrir a janela.")
        }
    }
}
#endif
