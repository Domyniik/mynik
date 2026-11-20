import Foundation

/// Erros da ligação à Shopify, com mensagens prontas a mostrar.
nonisolated enum ShopifyError: Error, Equatable, LocalizedError {
    case invalidDomain
    case unauthorized
    case missingScopes(String?)
    case shopNotFound
    case paymentRequired
    case throttled
    case server(Int)
    case graphQL([String])
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidDomain:
            "O endereço da loja tem de terminar em .myshopify.com."
        case .unauthorized:
            "Credenciais inválidas, revogadas ou o app não está instalado na loja."
        case .missingScopes(let detail):
            "Faltam permissões ao app personalizado." + (detail.map { " (\($0))" } ?? "")
        case .shopNotFound:
            "Loja não encontrada. Confirma o endereço .myshopify.com."
        case .paymentRequired:
            "A loja está bloqueada ou com o plano suspenso."
        case .throttled:
            "A Shopify pediu para abrandar. Tenta outra vez daqui a um minuto."
        case .server(let code):
            "A Shopify respondeu com um erro (\(code)). Tenta mais tarde."
        case .graphQL(let messages):
            messages.isEmpty ? "Resposta inesperada da Shopify." : messages.joined(separator: "\n")
        case .decoding:
            "Não foi possível ler a resposta da Shopify."
        case .network:
            "Sem ligação à internet ou à Shopify."
        }
    }
}
