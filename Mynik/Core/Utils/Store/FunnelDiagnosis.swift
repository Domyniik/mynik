import Foundation

/// Onde está o problema do funil da loja.
nonisolated enum FunnelProblem: String, Sendable {
    /// As visitas não adicionam ao carrinho.
    case pagePrice
    /// Adicionam ao carrinho, mas desistem no checkout.
    case checkoutShipping
    /// O funil converte bem; faltam visitas.
    case traffic
    case healthy
    case notEnoughData
    case noTrafficData

    var title: String {
        switch self {
        case .pagePrice: "Página ou preço"
        case .checkoutShipping: "Checkout ou frete"
        case .traffic: "Tráfego"
        case .healthy: "Funil saudável"
        case .notEnoughData: "Poucos dados"
        case .noTrafficData: "Sem dados de tráfego"
        }
    }

    var symbolName: String {
        switch self {
        case .pagePrice: "tag.slash"
        case .checkoutShipping: "shippingbox"
        case .traffic: "person.3"
        case .healthy: "checkmark.seal"
        case .notEnoughData: "hourglass"
        case .noTrafficData: "chart.line.downtrend.xyaxis"
        }
    }

    var explanation: String {
        switch self {
        case .pagePrice:
            "Quem visita a loja não adiciona ao carrinho: o produto, as fotos ou o preço não convencem."
        case .checkoutShipping:
            "Os clientes querem comprar mas desistem entre o carrinho e o pagamento, muitas vezes por portes ou custos inesperados."
        case .traffic:
            "Quem entra compra bem. O que limita as vendas é o número de visitas."
        case .healthy:
            "Todas as etapas estão dentro dos valores de referência."
        case .notEnoughData:
            "São precisas pelo menos 100 visitas no período para um diagnóstico fiável."
        case .noTrafficData:
            "Sem sessões da Shopify não é possível ver o funil. Confirma o scope read_reports do app."
        }
    }

    var suggestions: [String] {
        switch self {
        case .pagePrice:
            ["Melhorar as fotos e o vídeo do produto", "Testar o preço ou uma oferta (2 por X)", "Mostrar avaliações e prova social", "Rever o título e a descrição"]
        case .checkoutShipping:
            ["Mostrar os portes logo na página do produto", "Oferecer envio grátis a partir de um valor", "Ativar mais métodos de pagamento (MB WAY, Apple Pay)", "Recuperar carrinhos abandonados por e-mail"]
        case .traffic:
            ["Aumentar o orçamento dos anúncios que funcionam", "Publicar mais nas redes sociais", "Trabalhar o SEO das páginas de produto"]
        case .healthy, .notEnoughData, .noTrafficData:
            []
        }
    }
}

/// Uma etapa do funil, com a taxa face à etapa anterior.
nonisolated struct FunnelStage: Sendable, Equatable, Identifiable {
    enum Status: Sendable, Equatable {
        case good, ok, weak, none
    }

    var name: String
    var count: Int
    /// Taxa face à etapa anterior (`nil` na primeira).
    var rate: Double?
    var goodThreshold: Double?
    var weakThreshold: Double?

    var id: String { name }

    var status: Status {
        guard let rate, let goodThreshold, let weakThreshold else { return .none }
        if rate >= goodThreshold { return .good }
        if rate < weakThreshold { return .weak }
        return .ok
    }
}

/// Funil sessões → carrinho → checkout → compra e o diagnóstico.
nonisolated struct FunnelDiagnosis: Sendable, Equatable {
    static let minimumSessions = 100
    /// Abaixo disto por dia, um funil que converte bem é limitado pelo tráfego.
    static let lowTrafficPerDay = 50.0

    var stages: [FunnelStage]
    var sessionsPerDay: Double
    /// Compras por visita.
    var conversionRate: Double?
    var problem: FunnelProblem

    struct DayTotals: Sendable {
        var sessions = 0
        var cart = 0
        var checkout = 0
        var completed = 0
        var hasTraffic = false
    }

    static func diagnose(_ totals: DayTotals, days: Int) -> FunnelDiagnosis {
        let rate = { (part: Int, whole: Int) -> Double? in whole > 0 ? Double(part) / Double(whole) : nil }
        let stages = [
            FunnelStage(name: "Visitas", count: totals.sessions),
            FunnelStage(name: "Carrinho", count: totals.cart, rate: rate(totals.cart, totals.sessions), goodThreshold: 0.06, weakThreshold: 0.04),
            FunnelStage(name: "Checkout", count: totals.checkout, rate: rate(totals.checkout, totals.cart), goodThreshold: 0.5, weakThreshold: 0.35),
            FunnelStage(name: "Compra", count: totals.completed, rate: rate(totals.completed, totals.checkout), goodThreshold: 0.5, weakThreshold: 0.35),
        ]
        let perDay = Double(totals.sessions) / Double(max(1, days))

        let problem: FunnelProblem
        if !totals.hasTraffic {
            problem = .noTrafficData
        } else if totals.sessions < minimumSessions {
            problem = .notEnoughData
        } else if let weakest = stages.filter({ $0.status == .weak }).min(by: { relativeGap($0) < relativeGap($1) }) {
            problem = weakest.name == "Carrinho" ? .pagePrice : .checkoutShipping
        } else if perDay < lowTrafficPerDay {
            problem = .traffic
        } else {
            problem = .healthy
        }

        return FunnelDiagnosis(
            stages: stages,
            sessionsPerDay: perDay,
            conversionRate: rate(totals.completed, totals.sessions),
            problem: problem
        )
    }

    /// Taxa a dividir pelo limite de "fraco": quanto menor, pior.
    private static func relativeGap(_ stage: FunnelStage) -> Double {
        guard let rate = stage.rate, let weak = stage.weakThreshold, weak > 0 else { return .infinity }
        return rate / weak
    }
}

extension FunnelDiagnosis {
    /// Diagnóstico dos últimos `days` dias a partir das estatísticas diárias.
    static func diagnose(stats: [DailyStat], days: Int, now: Date = .now, calendar: Calendar = .current) -> FunnelDiagnosis {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        var totals = DayTotals()
        for stat in stats where stat.date >= start && stat.hasTraffic {
            totals.hasTraffic = true
            totals.sessions += stat.sessions
            totals.cart += stat.cartSessions
            totals.checkout += stat.checkoutSessions
            totals.completed += stat.completedSessions
        }
        return diagnose(totals, days: days)
    }
}
