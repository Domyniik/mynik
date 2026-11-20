import Foundation

/// Loja de exemplo (bijutaria) usada enquanto a Shopify não está ligada,
/// nas previews e nos testes.
///
/// É determinística: a mesma `now` e a mesma semente geram sempre os mesmos
/// pedidos. Cada produto tem um perfil para exercitar o ranking e os alertas.
nonisolated struct DemoStoreDataSource: StoreDataSource {
    var now: Date = .now
    var seed: UInt64 = 42
    var calendar: Calendar = .current

    static let shopName = "Neloce (exemplo)"

    private struct Profile {
        let id: Int
        let title: String
        /// Preço e custo em cêntimos (inteiros, para não perder precisão).
        let price: Int
        let cost: Int
        let ageDays: Int
        /// Vendas médias por dia.
        let rate: Double
        /// Probabilidade de cada unidade ser devolvida.
        let refundRate: Double
        let inventory: Int
        /// Dias sem vendas no fim da janela (produto "parado").
        var quietDays = 0
        var status = "ACTIVE"
        var adSpend: Int = 0
    }

    private static let profiles: [Profile] = [
        Profile(id: 1, title: "Colar Lua Dourada", price: 2990, cost: 750, ageDays: 120, rate: 1.6, refundRate: 0.02, inventory: 42, adSpend: 90),
        Profile(id: 2, title: "Brincos Pérola Mini", price: 1990, cost: 420, ageDays: 95, rate: 1.1, refundRate: 0.03, inventory: 65, adSpend: 40),
        Profile(id: 3, title: "Pulseira Fio Vermelho", price: 1490, cost: 310, ageDays: 70, rate: 0.45, refundRate: 0.05, inventory: 80),
        Profile(id: 4, title: "Anel Ajustável Onda", price: 2490, cost: 1380, ageDays: 80, rate: 0.25, refundRate: 0.25, inventory: 30, quietDays: 24, adSpend: 120),
        Profile(id: 5, title: "Conjunto Gargantilha + Brincos", price: 3990, cost: 1100, ageDays: 6, rate: 0.35, refundRate: 0, inventory: 20, adSpend: 25),
        Profile(id: 6, title: "Tornozeleira Conchas", price: 1290, cost: 390, ageDays: 90, rate: 0.15, refundRate: 0.1, inventory: 54, quietDays: 45),
        Profile(id: 7, title: "Colar Inicial Personalizado", price: 3490, cost: 600, ageDays: 50, rate: 0.7, refundRate: 0.04, inventory: 3),
        Profile(id: 8, title: "Porta-joias Veludo", price: 2200, cost: 800, ageDays: 3, rate: 0, refundRate: 0, inventory: 0, status: "DRAFT"),
    ]

    static func productID(_ number: Int) -> String { "gid://shopify/Product/\(1000 + number)" }

    func fetchSnapshot(since: Date) async throws -> StoreSnapshot {
        snapshot(since: since)
    }

    func snapshot(since: Date) -> StoreSnapshot {
        var random = SeededGenerator(seed: seed)
        let today = calendar.startOfDay(for: now)
        let days = max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: since), to: today).day ?? 0) + 1)

        let products = Self.profiles.map { profile in
            StoreSnapshot.ProductRecord(
                id: Self.productID(profile.id),
                title: profile.title,
                handle: profile.title.lowercased().replacingOccurrences(of: " ", with: "-"),
                status: profile.status,
                imageURL: "",
                price: Self.euros(profile.price),
                unitCost: Self.euros(profile.cost),
                inventory: profile.inventory,
                tracksInventory: true,
                createdAt: calendar.date(byAdding: .day, value: -profile.ageDays, to: today) ?? today,
                adSpend30d: Decimal(profile.adSpend)
            )
        }

        var orders: [StoreSnapshot.OrderRecord] = []
        var traffic: [StoreSnapshot.TrafficRecord] = []
        var number = 1001

        // Do dia mais antigo para hoje, para os números dos pedidos subirem.
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let isWeekend = calendar.isDateInWeekend(day)
            var dayOrders: [StoreSnapshot.OrderRecord] = []

            for profile in Self.profiles where profile.status == "ACTIVE" {
                let productAge = profile.ageDays - offset
                guard productAge >= 0, offset >= profile.quietDays else { continue }
                let rate = profile.rate * (isWeekend ? 1.3 : 1)
                for _ in 0..<poisson(rate, using: &random) {
                    let order = makeOrder(
                        number: number, day: day, isToday: offset == 0, ageDays: offset,
                        main: profile, using: &random
                    )
                    dayOrders.append(order)
                    number += 1
                }
            }

            // Hoje há sempre pelo menos uma venda, para o ecrã não ficar vazio.
            if offset == 0, dayOrders.isEmpty, let best = Self.profiles.first {
                dayOrders.append(makeOrder(number: number, day: day, isToday: true, ageDays: 0, main: best, using: &random))
                number += 1
            }
            orders += dayOrders.sorted { $0.createdAt < $1.createdAt }

            let sessions = Int.random(in: 180...260, using: &random) + (isWeekend ? 50 : 0)
            let cart = max(dayOrders.count + 2, Int(Double(sessions) * Double.random(in: 0.07...0.10, using: &random)))
            // Muitos desistem entre o carrinho e o checkout (portes): o diagnóstico aponta para aí.
            let checkout = max(dayOrders.count, Int(Double(cart) * Double.random(in: 0.26...0.36, using: &random)))
            traffic.append(.init(
                day: day,
                sessions: sessions,
                cartSessions: cart,
                checkoutSessions: checkout,
                completedSessions: dayOrders.count
            ))
        }

        return StoreSnapshot(
            shopName: Self.shopName,
            products: products,
            orders: orders,
            traffic: traffic,
            trafficUnavailableReason: nil
        )
    }

    private func makeOrder(
        number: Int,
        day: Date,
        isToday: Bool,
        ageDays: Int,
        main: Profile,
        using random: inout SeededGenerator
    ) -> StoreSnapshot.OrderRecord {
        // Hora da venda: hoje, só até à hora atual.
        let latestHour = isToday ? max(0, calendar.component(.hour, from: now) - 1) : 22
        let hour = Int.random(in: min(8, latestHour)...latestHour, using: &random)
        let createdAt = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...59, using: &random), second: 0, of: day) ?? day

        var picked = [(main, 1)]
        if Double.random(in: 0...1, using: &random) < 0.18,
           let extra = Self.profiles.filter({ $0.status == "ACTIVE" && $0.id != main.id && $0.ageDays >= ageDays }).randomElement(using: &random) {
            picked.append((extra, 1))
        }

        let lines = picked.map { profile, quantity in
            let refunded = Double.random(in: 0...1, using: &random) < profile.refundRate
            return StoreOrderLine(
                productID: Self.productID(profile.id),
                title: profile.title,
                quantity: quantity,
                currentQuantity: refunded ? 0 : quantity,
                unitPrice: Self.euros(profile.price)
            )
        }

        let originalSubtotal = lines.reduce(Decimal(0)) { $0 + $1.unitPrice * Decimal($1.quantity) }
        let subtotal = lines.reduce(Decimal(0)) { $0 + $1.unitPrice * Decimal($1.currentQuantity) }
        let shipping: Decimal = originalSubtotal >= 35 ? 0 : Self.euros(390)
        let refunded = originalSubtotal - subtotal
        let total = subtotal + (subtotal > 0 ? shipping : 0)
        let financialStatus = refunded == 0 ? "PAID" : (subtotal == 0 ? "REFUNDED" : "PARTIALLY_REFUNDED")

        // Pedidos com mais de 3 dias já foram enviados, exceto um esquecido.
        let isForgotten = ageDays == 5 && number % 2 == 0
        let fulfillment = (ageDays <= 2 || isForgotten) && subtotal > 0 ? "UNFULFILLED" : "FULFILLED"

        return StoreSnapshot.OrderRecord(
            id: "gid://shopify/Order/\(number)",
            name: "#\(number)",
            createdAt: createdAt,
            cancelledAt: nil,
            subtotal: subtotal,
            shipping: subtotal > 0 ? shipping : 0,
            tax: Self.includedVAT(in: total),
            total: total,
            refunded: refunded,
            currencyCode: Currency.defaultCode,
            financialStatus: financialStatus,
            fulfillmentStatus: fulfillment,
            lines: lines
        )
    }

    static func euros(_ cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    /// IVA de 23 % incluído no preço, arredondado ao cêntimo.
    static func includedVAT(in total: Decimal) -> Decimal {
        var vat = total * 23 / 123
        var rounded = Decimal()
        NSDecimalRound(&rounded, &vat, 2, .plain)
        return rounded
    }

    /// Número de eventos de um processo de Poisson (algoritmo de Knuth).
    private func poisson(_ lambda: Double, using random: inout SeededGenerator) -> Int {
        guard lambda > 0 else { return 0 }
        let limit = exp(-lambda)
        var count = 0
        var product = Double.random(in: 0...1, using: &random)
        while product > limit {
            count += 1
            product *= Double.random(in: 0...1, using: &random)
        }
        return count
    }
}

/// Gerador pseudo-aleatório com semente (SplitMix64), para dados reproduzíveis.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
