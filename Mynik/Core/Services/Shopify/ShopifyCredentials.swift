import Foundation

/// Como a app se autentica na Admin API.
nonisolated enum ShopifyAuth: Sendable, Equatable {
    /// App criado no Dev Dashboard: a app troca o Client ID e o Client secret
    /// por um token de 24 horas (client credentials grant) e renova-o sozinha.
    case clientCredentials(clientID: String, clientSecret: String)
    /// Token fixo (`shpat_…`) de um app personalizado antigo, criado no admin.
    case accessToken(String)
}

/// Ligação à loja: o domínio `.myshopify.com` (nas preferências) e os
/// segredos do app (só no Keychain).
nonisolated struct ShopifyCredentials: Sendable, Equatable {
    var shopDomain: String
    var auth: ShopifyAuth

    /// Scopes só de leitura que o app tem de ter (`read_reports` é o que dá
    /// acesso ao ShopifyQL, usado no funil de sessões).
    static let requiredScopes = ["read_products", "read_orders", "read_inventory", "read_reports", "read_analytics"]

    static let accessTokenKey = "shopify.adminAccessToken"
    static let clientIDKey = "shopify.clientID"
    static let clientSecretKey = "shopify.clientSecret"
    private static let suffix = ".myshopify.com"

    /// Aceita "neloce", "neloce.myshopify.com", "https://neloce.myshopify.com/admin"
    /// ou "admin.shopify.com/store/neloce" e devolve "neloce.myshopify.com".
    static func normalizedDomain(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }

        let adminPrefix = "admin.shopify.com/store/"
        if text.hasPrefix(adminPrefix) {
            text = String(text.dropFirst(adminPrefix.count))
        }
        if let slash = text.firstIndex(of: "/") {
            text = String(text[..<slash])
        }
        if !text.contains(".") {
            text += suffix
        }

        guard text.hasSuffix(suffix) else { return nil }
        let handle = text.dropLast(suffix.count)
        guard !handle.isEmpty,
              handle.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
        else { return nil }
        return text
    }

    /// Credenciais guardadas, ou `nil` se a loja ainda não foi ligada.
    static func load(defaults: UserDefaults = .standard) -> ShopifyCredentials? {
        guard let domain = defaults.string(forKey: SettingsKey.shopifyDomain), !domain.isEmpty else { return nil }

        if let clientID = KeychainService.string(for: clientIDKey), !clientID.isEmpty,
           let secret = KeychainService.string(for: clientSecretKey), !secret.isEmpty {
            return ShopifyCredentials(shopDomain: domain, auth: .clientCredentials(clientID: clientID, clientSecret: secret))
        }
        if let token = KeychainService.string(for: accessTokenKey), !token.isEmpty {
            return ShopifyCredentials(shopDomain: domain, auth: .accessToken(token))
        }
        return nil
    }

    func save(defaults: UserDefaults = .standard) throws {
        try Self.removeSecrets()
        switch auth {
        case .clientCredentials(let clientID, let clientSecret):
            try KeychainService.set(clientID, for: Self.clientIDKey)
            try KeychainService.set(clientSecret, for: Self.clientSecretKey)
        case .accessToken(let token):
            try KeychainService.set(token, for: Self.accessTokenKey)
        }
        defaults.set(shopDomain, forKey: SettingsKey.shopifyDomain)
    }

    static func remove(defaults: UserDefaults = .standard) throws {
        try removeSecrets()
        defaults.removeObject(forKey: SettingsKey.shopifyDomain)
    }

    private static func removeSecrets() throws {
        for key in [accessTokenKey, clientIDKey, clientSecretKey] {
            try KeychainService.delete(key)
        }
    }
}
