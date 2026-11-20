import Foundation

/// Lê a loja real através da Admin GraphQL API.
///
/// As páginas são pequenas de propósito: o custo pedido de cada query fica
/// bem abaixo do máximo de 1000 pontos, e o `ShopifyClient` espera quando o
/// balde de pontos está a acabar.
nonisolated struct ShopifyStoreDataSource: StoreDataSource {
    let client: ShopifyClient
    var maxProductPages = 10
    var maxOrderPages = 60
    var calendar: Calendar = .current

    func fetchSnapshot(since: Date) async throws -> StoreSnapshot {
        let shop = try await client.fetchShop()
        let products = try await fetchProducts()
        let orders = try await fetchOrders(since: since)

        var traffic: [StoreSnapshot.TrafficRecord] = []
        var trafficReason: String?
        do {
            traffic = try await fetchTraffic(since: since)
        } catch ShopifyError.missingScopes {
            trafficReason = "Sem acesso aos relatórios: adiciona o scope read_reports ao app."
        } catch let error as ShopifyError {
            trafficReason = error.localizedDescription
        }

        // Sem permissão para checkouts abandonados, o resto continua a funcionar.
        let checkouts = (try? await fetchAbandonedCheckouts(since: since)) ?? []

        return StoreSnapshot(
            shopName: shop.name,
            products: products,
            orders: orders,
            traffic: traffic,
            trafficUnavailableReason: trafficReason,
            checkouts: checkouts
        )
    }

    // MARK: - Produtos

    static let productsQuery = """
    query Products($cursor: String) {
      products(first: 50, after: $cursor, sortKey: CREATED_AT) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id title handle status createdAt totalInventory tracksInventory
          featuredMedia { preview { image { url } } }
          priceRangeV2 { minVariantPrice { amount } }
          variants(first: 1) { nodes { inventoryItem { unitCost { amount } } } }
        }
      }
    }
    """

    func fetchProducts() async throws -> [StoreSnapshot.ProductRecord] {
        var records: [StoreSnapshot.ProductRecord] = []
        var cursor: String?
        for _ in 0..<maxProductPages {
            let page = try await client.query(
                Self.productsQuery,
                variables: cursor.map { ["cursor": $0] } ?? [:],
                estimatedCost: 550,
                as: ProductsResponse.self
            ).products
            records += page.nodes.map(\.record)
            guard page.pageInfo.hasNextPage, let next = page.pageInfo.endCursor else { break }
            cursor = next
        }
        return records
    }

    // MARK: - Pedidos

    static let ordersQuery = """
    query Orders($cursor: String, $search: String!) {
      orders(first: 15, after: $cursor, query: $search, sortKey: CREATED_AT, reverse: true) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id name createdAt cancelledAt test currencyCode
          displayFinancialStatus displayFulfillmentStatus
          currentSubtotalPriceSet { shopMoney { amount } }
          currentShippingPriceSet { shopMoney { amount } }
          currentTotalTaxSet { shopMoney { amount } }
          currentTotalPriceSet { shopMoney { amount } }
          totalRefundedSet { shopMoney { amount } }
          lineItems(first: 10) {
            nodes {
              title quantity currentQuantity
              product { id }
              originalUnitPriceSet { shopMoney { amount } }
            }
          }
        }
      }
    }
    """

    /// Filtro de pesquisa da Shopify, ex.: `created_at:>=2026-09-21`.
    /// A data é escrita no fuso do calendário (a meia-noite local, não a de UTC).
    static func orderSearch(since: Date, calendar: Calendar) -> String {
        let day = since.formatted(Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day())
        return "created_at:>=\(day)"
    }

    func fetchOrders(since: Date) async throws -> [StoreSnapshot.OrderRecord] {
        var records: [StoreSnapshot.OrderRecord] = []
        var cursor: String?
        for _ in 0..<maxOrderPages {
            var variables = ["search": Self.orderSearch(since: since, calendar: calendar)]
            variables["cursor"] = cursor
            let page = try await client.query(
                Self.ordersQuery,
                variables: variables,
                estimatedCost: 800,
                as: OrdersResponse.self
            ).orders
            records += page.nodes.filter { !$0.test }.map(\.record)
            guard page.pageInfo.hasNextPage, let next = page.pageInfo.endCursor else { break }
            cursor = next
        }
        return records
    }

    // MARK: - Checkouts abandonados

    static let checkoutsQuery = """
    query Checkouts($cursor: String, $search: String!) {
      abandonedCheckouts(first: 25, after: $cursor, query: $search, sortKey: CREATED_AT, reverse: true) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id name createdAt abandonedCheckoutUrl
          totalPriceSet { shopMoney { amount } }
          lineItems(first: 10) { nodes { title quantity product { id } } }
        }
      }
    }
    """

    func fetchAbandonedCheckouts(since: Date) async throws -> [StoreSnapshot.CheckoutRecord] {
        var records: [StoreSnapshot.CheckoutRecord] = []
        var cursor: String?
        for _ in 0..<10 {
            var variables = ["search": Self.orderSearch(since: since, calendar: calendar) + " recovery_state:not_recovered"]
            variables["cursor"] = cursor
            let page = try await client.query(
                Self.checkoutsQuery,
                variables: variables,
                estimatedCost: 600,
                as: CheckoutsResponse.self
            ).abandonedCheckouts
            records += page.nodes.map(\.record)
            guard page.pageInfo.hasNextPage, let next = page.pageInfo.endCursor else { break }
            cursor = next
        }
        return records
    }

    // MARK: - Tráfego (ShopifyQL)

    static let trafficQuery = """
    query Traffic($shopifyql: String!) {
      shopifyqlQuery(query: $shopifyql) {
        parseErrors
        tableData { rows }
      }
    }
    """

    static func trafficShopifyQL(days: Int) -> String {
        "FROM sessions SHOW sessions, sessions_with_cart_additions, sessions_that_reached_checkout, "
            + "sessions_that_completed_checkout TIMESERIES day SINCE -\(days)d UNTIL today"
    }

    func fetchTraffic(since: Date) async throws -> [StoreSnapshot.TrafficRecord] {
        let days = max(1, (calendar.dateComponents([.day], from: since, to: .now).day ?? 60) + 1)
        let response = try await client.query(
            Self.trafficQuery,
            variables: ["shopifyql": Self.trafficShopifyQL(days: days)],
            estimatedCost: 20,
            as: TrafficResponse.self
        ).shopifyqlQuery

        if !response.parseErrors.isEmpty {
            throw ShopifyError.graphQL(response.parseErrors)
        }
        return Self.trafficRecords(from: response.tableData?.rows ?? [], calendar: calendar)
    }

    /// Converte as linhas do ShopifyQL (`{"day": "2026-11-01", "sessions": 12, …}`).
    static func trafficRecords(
        from rows: [[String: ShopifyQLValue]],
        calendar: Calendar
    ) -> [StoreSnapshot.TrafficRecord] {
        rows.compactMap { row in
            guard let dayText = row["day"]?.text, let day = localDay(dayText, calendar: calendar) else { return nil }
            return StoreSnapshot.TrafficRecord(
                day: day,
                sessions: row["sessions"]?.integer ?? 0,
                cartSessions: row["sessions_with_cart_additions"]?.integer ?? 0,
                checkoutSessions: row["sessions_that_reached_checkout"]?.integer ?? 0,
                completedSessions: row["sessions_that_completed_checkout"]?.integer ?? 0
            )
        }
    }

    /// "2026-11-01" (ou "2026-11-01T00:00:00Z") → início desse dia no fuso local.
    static func localDay(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Valor de uma célula do ShopifyQL (texto, número ou nulo).
nonisolated enum ShopifyQLValue: Decodable, Sendable, Equatable {
    case text(String)
    case number(Double)
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let flag = try? container.decode(Bool.self) {
            self = .number(flag ? 1 : 0)
        } else {
            self = .null
        }
    }

    var text: String? {
        switch self {
        case .text(let value): value
        case .number(let value): String(value)
        case .null: nil
        }
    }

    var integer: Int? {
        switch self {
        case .number(let value): Int(value.rounded())
        case .text(let value): Double(value).map { Int($0.rounded()) }
        case .null: nil
        }
    }
}

// MARK: - Formato das respostas

private nonisolated struct PageInfo: Decodable, Sendable {
    let hasNextPage: Bool
    let endCursor: String?
}

private nonisolated struct Connection<Node: Decodable & Sendable>: Decodable, Sendable {
    let pageInfo: PageInfo
    let nodes: [Node]
}

private nonisolated struct Nodes<Node: Decodable & Sendable>: Decodable, Sendable {
    let nodes: [Node]
}

private nonisolated struct ProductsResponse: Decodable, Sendable {
    let products: Connection<ProductNode>
}

private nonisolated struct ProductNode: Decodable, Sendable {
    let id: String
    let title: String
    let handle: String
    let status: String
    let createdAt: Date
    let totalInventory: Int
    let tracksInventory: Bool
    let featuredMedia: Media?
    let priceRangeV2: PriceRange
    let variants: Nodes<Variant>

    struct Media: Decodable, Sendable { let preview: Preview? }
    struct Preview: Decodable, Sendable { let image: Image? }
    struct Image: Decodable, Sendable { let url: String }
    struct PriceRange: Decodable, Sendable { let minVariantPrice: ShopifyMoney }
    struct Variant: Decodable, Sendable { let inventoryItem: InventoryItem? }
    struct InventoryItem: Decodable, Sendable { let unitCost: ShopifyMoney? }

    var record: StoreSnapshot.ProductRecord {
        StoreSnapshot.ProductRecord(
            id: id,
            title: title,
            handle: handle,
            status: status,
            imageURL: featuredMedia?.preview?.image?.url ?? "",
            price: priceRangeV2.minVariantPrice.amount,
            unitCost: variants.nodes.first?.inventoryItem?.unitCost?.amount,
            inventory: totalInventory,
            tracksInventory: tracksInventory,
            createdAt: createdAt
        )
    }
}

private nonisolated struct OrdersResponse: Decodable, Sendable {
    let orders: Connection<OrderNode>
}

private nonisolated struct OrderNode: Decodable, Sendable {
    let id: String
    let name: String
    let createdAt: Date
    let cancelledAt: Date?
    let test: Bool
    let currencyCode: String
    let displayFinancialStatus: String?
    let displayFulfillmentStatus: String
    let currentSubtotalPriceSet: ShopifyMoneyBag
    let currentShippingPriceSet: ShopifyMoneyBag
    let currentTotalTaxSet: ShopifyMoneyBag
    let currentTotalPriceSet: ShopifyMoneyBag
    let totalRefundedSet: ShopifyMoneyBag
    let lineItems: Nodes<LineItem>

    struct LineItem: Decodable, Sendable {
        let title: String
        let quantity: Int
        let currentQuantity: Int
        let product: ProductReference?
        let originalUnitPriceSet: ShopifyMoneyBag
    }

    struct ProductReference: Decodable, Sendable { let id: String }

    var record: StoreSnapshot.OrderRecord {
        StoreSnapshot.OrderRecord(
            id: id,
            name: name,
            createdAt: createdAt,
            cancelledAt: cancelledAt,
            subtotal: currentSubtotalPriceSet.shopMoney.amount,
            shipping: currentShippingPriceSet.shopMoney.amount,
            tax: currentTotalTaxSet.shopMoney.amount,
            total: currentTotalPriceSet.shopMoney.amount,
            refunded: totalRefundedSet.shopMoney.amount,
            currencyCode: currencyCode,
            financialStatus: displayFinancialStatus ?? "",
            fulfillmentStatus: displayFulfillmentStatus,
            lines: lineItems.nodes.map {
                StoreOrderLine(
                    productID: $0.product?.id ?? "",
                    title: $0.title,
                    quantity: $0.quantity,
                    currentQuantity: $0.currentQuantity,
                    unitPrice: $0.originalUnitPriceSet.shopMoney.amount
                )
            }
        )
    }
}

private nonisolated struct CheckoutsResponse: Decodable, Sendable {
    let abandonedCheckouts: Connection<CheckoutNode>
}

private nonisolated struct CheckoutNode: Decodable, Sendable {
    let id: String
    let name: String
    let createdAt: Date
    let abandonedCheckoutUrl: String
    let totalPriceSet: ShopifyMoneyBag
    let lineItems: Nodes<LineItem>

    struct LineItem: Decodable, Sendable {
        let title: String?
        let quantity: Int
        let product: ProductReference?
    }

    struct ProductReference: Decodable, Sendable { let id: String }

    var record: StoreSnapshot.CheckoutRecord {
        StoreSnapshot.CheckoutRecord(
            id: id,
            name: name,
            createdAt: createdAt,
            total: totalPriceSet.shopMoney.amount,
            recoveryURL: abandonedCheckoutUrl,
            lines: lineItems.nodes.map {
                StoreCheckoutLine(productID: $0.product?.id ?? "", title: $0.title ?? "Artigo", quantity: $0.quantity)
            }
        )
    }
}

private nonisolated struct TrafficResponse: Decodable, Sendable {
    let shopifyqlQuery: Result

    struct Result: Decodable, Sendable {
        let parseErrors: [String]
        let tableData: Table?
    }

    struct Table: Decodable, Sendable {
        let rows: [[String: ShopifyQLValue]]
    }
}
