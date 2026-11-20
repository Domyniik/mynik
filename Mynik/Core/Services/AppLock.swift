import Foundation
import LocalAuthentication
import Observation

/// Bloqueio opcional da app com Face ID / Touch ID (ou o código do dispositivo).
///
/// Desligado por omissão; liga-se nas Definições. Volta a bloquear quando a app
/// passa mais de `gracePeriod` em segundo plano.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()
    /// Uma ida rápida a outra app não pede autenticação de novo.
    nonisolated static let gracePeriod: TimeInterval = 30

    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private(set) var message: String?

    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = AppEnvironment.defaults) {
        self.defaults = defaults
        // Os testes nunca ficam bloqueados.
        isLocked = !AppEnvironment.isRunningTests && (defaults.object(forKey: SettingsKey.appLockEnabled) as? Bool ?? false)
    }

    var isEnabled: Bool {
        defaults.object(forKey: SettingsKey.appLockEnabled) as? Bool ?? false
    }

    /// Deve voltar a bloquear depois de `elapsed` segundos em segundo plano?
    nonisolated static func shouldLock(isEnabled: Bool, backgroundedAt: Date?, now: Date, grace: TimeInterval = gracePeriod) -> Bool {
        guard isEnabled, let backgroundedAt else { return false }
        return now.timeIntervalSince(backgroundedAt) >= grace
    }

    func didEnterBackground(at date: Date = .now) {
        backgroundedAt = date
    }

    func didBecomeActive(at date: Date = .now) {
        if Self.shouldLock(isEnabled: isEnabled, backgroundedAt: backgroundedAt, now: date) {
            isLocked = true
        }
        backgroundedAt = nil
    }

    /// Ao desligar nas Definições, desbloqueia logo.
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: SettingsKey.appLockEnabled)
        if !enabled { isLocked = false }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await Self.authenticate(reason: "Desbloquear o Mynik") {
            isLocked = false
            message = nil
        } else {
            message = "Não foi possível confirmar a tua identidade."
        }
    }

    /// Pede Face ID / Touch ID, com o código do dispositivo como alternativa.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Sem código nem biometria não há como proteger: não prende o utilizador fora.
            return (error as? LAError)?.code == .passcodeNotSet
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
