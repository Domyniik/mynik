import Foundation

/// Cliente mínimo da Shopify Admin GraphQL API (só leitura).
///
/// - Autenticação: token fixo, ou client credentials grant (token de 24 h
///   pedido e renovado automaticamente).
/// - Limite por custo: guarda o `throttleStatus` de cada resposta e espera o
///   necessário antes do pedido seguinte; se mesmo assim receber `THROTTLED`
///   (ou HTTP 429), espera e tenta de novo.
actor ShopifyClient {
    nonisolated static let apiVersion = "2026-10"

    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    typealias Sleeper = @Sendable (TimeInterval) async throws -> Void

    nonisolated let credentials: ShopifyCredentials
    private let transport: Transport
    private let sleep: Sleeper
    private let maxRetries: Int
    private var throttle = ShopifyThrottle()
    private var cachedToken: AccessToken?

    /// Scopes concedidos ao token (só conhecidos com client credentials).
    private(set) var grantedScopes: [String] = []

    init(
        credentials: ShopifyCredentials,
        maxRetries: Int = 3,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) },
        sleep: @escaping Sleeper = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.credentials = credentials
        self.maxRetries = maxRetries
        self.transport = transport
        self.sleep = sleep
    }

    nonisolated var graphQLEndpoint: URL? {
        URL(string: "https://\(credentials.shopDomain)/admin/api/\(Self.apiVersion)/graphql.json")
    }

    nonisolated var tokenEndpoint: URL? {
        URL(string: "https://\(credentials.shopDomain)/admin/oauth/access_token")
    }

    /// Executa uma query e devolve o campo `data` descodificado.
    ///
    /// - Parameter estimatedCost: custo esperado em pontos, usado para esperar
    ///   antes de enviar quando o balde está quase vazio.
    func query<Response: Decodable & Sendable>(
        _ document: String,
        variables: [String: String] = [:],
        estimatedCost: Double = 50,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        var cost = estimatedCost
        var attempt = 0
        var refreshedToken = false

        while true {
            let wait = throttle.delay(beforeSpending: cost, at: .now)
            if wait > 0 { try await sleep(wait) }

            let token = try await accessToken(forceRefresh: false)
            let (data, response) = try await send(try graphQLRequest(document, variables: variables, token: token))

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200
            switch statusCode {
            case 200..<300:
                break
            case 401:
                // Um token de 24 h pode ter sido revogado antes do tempo: renova uma vez.
                guard case .clientCredentials = credentials.auth, !refreshedToken else { throw ShopifyError.unauthorized }
                refreshedToken = true
                cachedToken = nil
                continue
            case 402: throw ShopifyError.paymentRequired
            case 403: throw ShopifyError.missingScopes(nil)
            case 404: throw ShopifyError.shopNotFound
            case 429, 500...:
                guard attempt < maxRetries else {
                    throw statusCode == 429 ? ShopifyError.throttled : ShopifyError.server(statusCode)
                }
                attempt += 1
                try await sleep(retryAfter(response) ?? Double(attempt * 2))
                continue
            default:
                throw ShopifyError.server(statusCode)
            }

            let envelope: Envelope<Response>
            do {
                envelope = try ShopifyJSON.decoder().decode(Envelope<Response>.self, from: data)
            } catch {
                throw ShopifyError.decoding(String(describing: error))
            }

            if let status = envelope.extensions?.cost?.throttleStatus {
                throttle.record(status, at: .now)
            }

            let errors = envelope.errors ?? []
            if errors.contains(where: { $0.code == "THROTTLED" }) {
                guard attempt < maxRetries else { throw ShopifyError.throttled }
                attempt += 1
                cost = max(cost, envelope.extensions?.cost?.requestedQueryCost ?? cost)
                continue
            }
            if let denied = errors.first(where: { $0.code == "ACCESS_DENIED" }) {
                throw ShopifyError.missingScopes(denied.message)
            }
            guard let result = envelope.data else {
                throw ShopifyError.graphQL(errors.map(\.message))
            }
            return result
        }
    }

    /// Confirma a ligação e devolve o nome e a moeda da loja.
    func fetchShop() async throws -> ShopInfo {
        try await query(ShopInfo.query, estimatedCost: 1, as: ShopInfo.Response.self).shop
    }

    // MARK: - Token

    private func accessToken(forceRefresh: Bool) async throws -> String {
        switch credentials.auth {
        case .accessToken(let token):
            return token
        case .clientCredentials(let clientID, let clientSecret):
            if !forceRefresh, let cachedToken, cachedToken.expiresAt > Date.now.addingTimeInterval(60) {
                return cachedToken.value
            }
            let token = try await requestToken(clientID: clientID, clientSecret: clientSecret)
            cachedToken = token
            return token.value
        }
    }

    private func requestToken(clientID: String, clientSecret: String) async throws -> AccessToken {
        guard let tokenEndpoint else { throw ShopifyError.invalidDomain }
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Self.formBody([
            ("grant_type", "client_credentials"),
            ("client_id", clientID),
            ("client_secret", clientSecret),
        ])

        let (data, response) = try await send(request)
        switch (response as? HTTPURLResponse)?.statusCode ?? 200 {
        case 200..<300: break
        case 400, 401, 403: throw ShopifyError.unauthorized
        case 404: throw ShopifyError.shopNotFound
        case let code: throw ShopifyError.server(code)
        }

        guard let grant = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw ShopifyError.decoding("access_token")
        }
        grantedScopes = (grant.scope ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let lifetime = TimeInterval(grant.expires_in ?? 86_399)
        return AccessToken(value: grant.access_token, expiresAt: Date.now.addingTimeInterval(lifetime))
    }

    /// Corpo `application/x-www-form-urlencoded`.
    nonisolated static func formBody(_ fields: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    // MARK: - Rede

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await transport(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ShopifyError.network(error.localizedDescription)
        }
    }

    private func graphQLRequest(_ document: String, variables: [String: String], token: String) throws -> URLRequest {
        guard let graphQLEndpoint else { throw ShopifyError.invalidDomain }
        var request = URLRequest(url: graphQLEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Shopify-Access-Token")
        request.httpBody = try JSONEncoder().encode(RequestBody(query: document, variables: variables))
        return request
    }

    private func retryAfter(_ response: URLResponse) -> TimeInterval? {
        guard let value = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(value)
    }
}

/// Dados básicos da loja, usados para testar a ligação.
nonisolated struct ShopInfo: Decodable, Sendable, Equatable {
    var name: String
    var myshopifyDomain: String
    var currencyCode: String

    static let query = "{ shop { name myshopifyDomain currencyCode } }"

    struct Response: Decodable, Sendable {
        var shop: ShopInfo
    }
}

// MARK: - Formato dos pedidos e das respostas

private nonisolated struct AccessToken: Sendable {
    let value: String
    let expiresAt: Date
}

private nonisolated struct TokenResponse: Decodable {
    let access_token: String
    let scope: String?
    let expires_in: Int?
}

private nonisolated struct RequestBody: Encodable {
    let query: String
    let variables: [String: String]
}

private nonisolated struct Envelope<Payload: Decodable>: Decodable {
    let data: Payload?
    let errors: [GraphQLError]?
    let extensions: Extensions?

    struct GraphQLError: Decodable {
        let message: String
        let extensions: ErrorExtensions?

        var code: String? { extensions?.code }
    }

    struct ErrorExtensions: Decodable {
        let code: String?
    }

    struct Extensions: Decodable {
        let cost: Cost?
    }

    struct Cost: Decodable {
        let requestedQueryCost: Double?
        let actualQueryCost: Double?
        let throttleStatus: ShopifyThrottleStatus?
    }
}
