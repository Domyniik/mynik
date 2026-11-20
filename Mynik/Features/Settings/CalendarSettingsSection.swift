import SwiftUI

/// Calendário e Lembretes na tela Hoje.
struct CalendarSettingsSection: View {
    @AppStorage(SettingsKey.showCalendarOnToday) private var isEnabled = true

    var body: some View {
        Section {
            Toggle("Mostrar eventos e lembretes em Hoje", isOn: $isEnabled)
        } header: {
            Text("Calendário e Lembretes")
        } footer: {
            Text("Os eventos e os lembretes são lidos no dispositivo e nunca saem dele.")
        }
    }
}
