import Foundation
import LocalAuthentication
import Observation

/// Cofre dos documentos: números e fotos só aparecem depois do Face ID / Touch ID
/// (ou do código do dispositivo). Volta a fechar quando a app vai para segundo plano.
@MainActor
@Observable
final class BiometricLock {
    static let shared = BiometricLock()

    private(set) var isUnlocked = false
    private(set) var message: String?

    /// Nome do método disponível, para o botão ("Face ID", "Touch ID"...).
    var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return switch context.biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "código"
        }
    }

    var symbolName: String {
        methodName == "Touch ID" ? "touchid" : methodName == "código" ? "lock" : "faceid"
    }

    func unlock(reason: String = "Mostrar os números e as fotos dos teus documentos") async {
        guard !isUnlocked else { return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if (error as? LAError)?.code == .passcodeNotSet {
                // Sem código nem biometria não há como proteger: abre, mas avisa.
                isUnlocked = true
                message = "Define um código no dispositivo para proteger os documentos."
            } else {
                message = "Autenticação indisponível neste dispositivo."
            }
            return
        }
        do {
            isUnlocked = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            message = nil
        } catch {
            message = (error as? LAError)?.code == .userCancel ? nil : "Não foi possível confirmar a tua identidade."
        }
    }

    func lock() {
        isUnlocked = false
    }
}
