import SwiftData
import SwiftUI
import UserNotifications

/// Lembretes de vencimento das contas a pagar.
struct NotificationSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @AppStorage(SettingsKey.billRemindersEnabled) private var isEnabled = true
    @AppStorage(SettingsKey.billReminderDaysBefore) private var daysBefore = 1

    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Section {
            Toggle("Lembrar contas a pagar", isOn: $isEnabled)

            if isEnabled {
                Stepper(value: $daysBefore, in: 0...7) {
                    LabeledContent("Avisar antes", value: daysBeforeText)
                }

                if status == .denied {
                    Button("Permitir notificações nos Ajustes", systemImage: "bell.slash") {
                        openSystemSettings()
                    }
                    .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Notificações")
        } footer: {
            Text("Recebes um aviso às 9:00 no dia do vencimento e, se quiseres, alguns dias antes.")
        }
        .task {
            // Só lê o estado: o pedido de permissão fica para quando há contas
            // ou quando o utilizador liga o interruptor.
            status = await NotificationService.shared.authorizationStatus()
        }
        .onChange(of: isEnabled) {
            Task { await reschedule(askingPermission: isEnabled) }
        }
        .onChange(of: daysBefore) {
            Task { await reschedule(askingPermission: false) }
        }
    }

    private var daysBeforeText: String {
        switch daysBefore {
        case 0: "Só no dia"
        case 1: "1 dia"
        default: "\(daysBefore) dias"
        }
    }

    private func reschedule(askingPermission: Bool) async {
        if askingPermission {
            await NotificationService.shared.requestAuthorizationIfNeeded()
        }
        status = await NotificationService.shared.authorizationStatus()
        await NotificationService.shared.rescheduleBillReminders(in: modelContext)
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            openURL(url)
        }
        #endif
    }
}
