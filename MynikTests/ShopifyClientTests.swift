import Foundation
import Testing
@testable import Mynik

/// Devolve respostas pré-definidas e regista os pedidos recebidos.
actor StubTransport {
    struct Reply {
        var status: Int = 200
        var body: String
    }

    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) {
        self.replies = replies
    }

    func handle(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        return (Data(reply.body.utf8), response)
    }
}

actor SleepRecorder {
    private(set) var durations: [TimeInterval] = []
    func record(_ seconds: TimeInterval) { durations.append(seconds) }
}

struct ShopifyClientTests {
    private let shopBody = """
    {"data":{"shop":{"name":"Neloce","myshopifyDomain":"neloce.myshopify.com","currencyCode":"EUR"}},
     "extensions":{"cost":{"requestedQueryCost":1,"actualQueryCost":1,
       "throttleStatus":{"maximumAvailable":2000,"currentlyAvailable":1999,"restoreRate":100}}}}
    """

    private func makeClient(
        _ replies: [StubTransport.Reply],
        auth: ShopifyAuth = .accessToken("shpat_teste")
    ) -> (ShopifyClient, StubTransport, SleepRecorder) {
        let stub = StubTransport(replies)
        let sleeps = SleepRecorder()
        let client = ShopifyClient(
            credentials: ShopifyCredentials(shopDomain: "neloce.myshopify.com", auth: auth),
            transport: { try await stub.handle($0) },
            sleep: { await sleeps.record($0) }
        )
        return (client, stub, sleeps)
    }

    @Test(arguments: [
        ("neloce", "neloce.myshopify.com"),
        ("  Neloce.myshopify.com ", "neloce.myshopify.com"),
        ("https://neloce.myshopify.com/admin/products", "neloce.myshopify.com"),
        ("admin.shopify.com/store/neloce-2", "neloce-2.myshopify.com"),
    ])
    func normalizesShopDomain(input: String, expected: String) {
        #expect(ShopifyCredentials.normalizedDomain(input) == expected)
    }

    @Test(arguments: ["", "neloce.com", "loja com espaços", "https://.myshopify.com"])
    func rejectsInvalidDomains(input: String) {
        #expect(ShopifyCredentials.normalizedDomain(input) == nil)
    }

    @Test func throttleWaitsOnlyForMissingPoints() {
        var throttle = ShopifyThrottle()
        let start = Date(timeIntervalSince1970: 0)
        #expect(throttle.delay(beforeSpending: 500, at: start) == 0)

        throttle.record(.init(maximumAvailable: 2000, currentlyAvailable: 100, restoreRate: 100), at: start)
        #expect(throttle.delay(beforeSpending: 500, at: start) == 4)
        // Passados 2 s já repôs 200 pontos: faltam 200, ou seja, 2 s.
        #expect(throttle.delay(beforeSpending: 500, at: start.addingTimeInterval(2)) == 2)
        #expect(throttle.delay(beforeSpending: 50, at: start) == 0)
        // Nunca passa do máximo do balde.
        #expect(throttle.available(at: start.addingTimeInterval(1000)) == 2000)
    }

    @Test func sendsTokenHeaderAndDecodesShop() async throws {
        let (client, stub, _) = makeClient([.init(body: shopBody)])

        let shop = try await client.fetchShop()

        #expect(shop == ShopInfo(name: "Neloce", myshopifyDomain: "neloce.myshopify.com", currencyCode: "EUR"))
        let request = try #require(await stub.requests.first)
        #expect(request.url?.absoluteString == "https://neloce.myshopify.com/admin/api/\(ShopifyClient.apiVersion)/graphql.json")
        #expect(request.value(forHTTPHeaderField: "X-Shopify-Access-Token") == "shpat_teste")
    }

    @Test func exchangesClientCredentialsForTokenOnce() async throws {
        let tokenBody = #"{"access_token":"tok_123","scope":"read_products,read_orders","expires_in":86399}"#
        let (client, stub, _) = makeClient(
            [.init(body: tokenBody), .init(body: shopBody), .init(body: shopBody)],
            auth: .clientCredentials(clientID: "id-1", clientSecret: "se/cr+et")
        )

        _ = try await client.fetchShop()
        _ = try await client.fetchShop()

        let requests = await stub.requests
        #expect(requests.count == 3)
        #expect(requests[0].url?.path == "/admin/oauth/access_token")
        let form = String(decoding: requests[0].httpBody ?? Data(), as: UTF8.self)
        #expect(form == "grant_type=client_credentials&client_id=id-1&client_secret=se%2Fcr%2Bet")
        #expect(requests[1].value(forHTTPHeaderField: "X-Shopify-Access-Token") == "tok_123")
        #expect(requests[2].value(forHTTPHeaderField: "X-Shopify-Access-Token") == "tok_123")
        #expect(await client.grantedScopes == ["read_products", "read_orders"])
    }

    @Test func retriesAfterThrottledError() async throws {
        let throttled = """
        {"errors":[{"message":"Throttled","extensions":{"code":"THROTTLED"}}],
         "extensions":{"cost":{"requestedQueryCost":300,"actualQueryCost":null,
           "throttleStatus":{"maximumAvailable":2000,"currentlyAvailable":100,"restoreRate":100}}}}
        """
        let (client, stub, sleeps) = makeClient([.init(body: throttled), .init(body: shopBody)])

        let shop = try await client.fetchShop()

        #expect(shop.name == "Neloce")
        #expect(await stub.requests.count == 2)
        // Esperou o tempo para repor os 200 pontos em falta (≈2 s).
        let waited = try #require(await sleeps.durations.first)
        #expect(waited > 1.9 && waited <= 2)
    }

    @Test func mapsHTTPAndAccessErrors() async {
        let (unauthorized, _, _) = makeClient([.init(status: 401, body: "")])
        await #expect(throws: ShopifyError.unauthorized) { try await unauthorized.fetchShop() }

        let denied = #"{"errors":[{"message":"Access denied for shopifyqlQuery","extensions":{"code":"ACCESS_DENIED"}}]}"#
        let (forbidden, _, _) = makeClient([.init(body: denied)])
        await #expect(throws: ShopifyError.missingScopes("Access denied for shopifyqlQuery")) { try await forbidden.fetchShop() }
    }

    @Test func decodesMoneyStringsAndDates() throws {
        let json = #"{"amount":"12.50"}"#
        let money = try ShopifyJSON.decoder().decode(ShopifyMoney.self, from: Data(json.utf8))
        #expect(money.amount == Decimal(string: "12.50"))
        #expect(ShopifyJSON.parseDate("2026-11-20T10:00:00Z") != nil)
        #expect(ShopifyJSON.parseDate("2026-11-20T10:00:00.123Z") != nil)
    }
}

