import Auth
import Foundation

/// Guarda a sessão do Supabase no Keychain, com o mesmo serviço dos outros segredos.
///
/// O armazenamento por omissão da biblioteca usa o Keychain de proteção de dados,
/// que fora do iOS exige um perfil de provisionamento (plano pago).
nonisolated struct KeychainAuthStorage: AuthLocalStorage {
    private func account(_ key: String) -> String { "supabase.\(key)" }

    func store(key: String, value: Data) throws {
        try KeychainService.set(value.base64EncodedString(), for: account(key))
    }

    func retrieve(key: String) throws -> Data? {
        KeychainService.string(for: account(key)).flatMap { Data(base64Encoded: $0) }
    }

    func remove(key: String) throws {
        try KeychainService.delete(account(key))
    }
}
