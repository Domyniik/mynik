import SwiftUI

/// Ecrã que tapa a app enquanto está bloqueada (e no seletor de apps).
struct AppLockView: View {
    let lock: AppLock
    /// `false` quando só tapa o conteúdo no seletor de apps.
    var asksForUnlock = true

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Mynik bloqueado")
                    .font(.title2.bold())
                if asksForUnlock {
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Desbloquear com \(BiometricLock.shared.methodName)", systemImage: BiometricLock.shared.symbolName)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(lock.isAuthenticating)
                    if let message = lock.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .accessibilityAddTraits(.isModal)
        // Pede logo a autenticação quando a app fica ativa (no arranque ainda não está).
        .task(id: asksForUnlock) {
            if asksForUnlock { await lock.unlock() }
        }
    }
}

/// Definições: Face ID para abrir a app.
struct AppLockSettingsSection: View {
    @State private var lock = AppLock.shared
    @State private var isEnabled = AppLock.shared.isEnabled

    var body: some View {
        Section {
            Toggle("Pedir \(BiometricLock.shared.methodName) ao abrir", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, enabled in
                    guard enabled != lock.isEnabled else { return }
                    Task {
                        // Confirma que funciona antes de ligar (evita ficar preso fora da app).
                        if enabled, await !AppLock.authenticate(reason: "Ativar o bloqueio do Mynik") {
                            isEnabled = false
                            return
                        }
                        lock.setEnabled(enabled)
                    }
                }
        } header: {
            Text("Privacidade")
        } footer: {
            Text("A app volta a bloquear depois de 30 segundos em segundo plano e fica tapada no seletor de apps. Os números e as fotos dos documentos continuam a pedir autenticação à parte.")
        }
    }
}
