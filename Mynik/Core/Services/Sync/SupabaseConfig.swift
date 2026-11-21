import Foundation

/// Projeto Supabase usado no login e no sync.
///
/// Os valores vêm do Info.plist, preenchido a partir de `Config/Supabase.xcconfig`
/// (fora do git). Só a chave pública (anon); a service_role nunca entra na app.
nonisolated struct SupabaseConfig: Equatable, Sendable {
    var url: URL
    var anonKey: String

    var authURL: URL { url.appending(path: "auth/v1") }
    var restURL: URL { url.appending(path: "rest/v1") }

    /// `nil` se a versão foi compilada sem configuração (o login fica escondido).
    static var fromBundle: SupabaseConfig? {
        let info = Bundle.main.infoDictionary ?? [:]
        return make(
            projectRef: info["SupabaseProjectRef"] as? String ?? "",
            anonKey: info["SupabaseAnonKey"] as? String ?? ""
        )
    }

    /// Aceita o "Reference ID" (`abcd…`) ou o anfitrião completo (`abcd.supabase.co`).
    static func make(projectRef: String, anonKey: String) -> SupabaseConfig? {
        let ref = projectRef.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty, !key.isEmpty, !ref.contains("$(") else { return nil }
        let host = ref.contains(".") ? ref : "\(ref).supabase.co"
        guard let url = URL(string: "https://\(host)") else { return nil }
        return SupabaseConfig(url: url, anonKey: key)
    }
}
