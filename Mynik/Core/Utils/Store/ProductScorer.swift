import Foundation

/// Classificação de um produto no ranking.
nonisolated enum ProductClass: String, CaseIterable, Identifiable, Sendable {
    case winner
    case promising
    case testing
    case loser

    var id: Self { self }

    var emoji: String {
        switch self {
        case .winner: "🟢"
        case .promising: "🟡"
        case .testing: "🟠"
        case .loser: "🔴"
        }
    }

    var title: String {
        switch self {
        case .winner: "Vencedor"
        case .promising: "Promissor"
        case .testing: "Em teste"
        case .loser: "Perdedor"
        }
    }
}

/// Resultado do ranking de um produto.
nonisolated struct ProductScore: Sendable, Equatable {
    struct Factor: Sendable, Equatable, Identifiable {
        enum Kind: String, Sendable {
            case sales, revenue, margin, funnel, refunds, recency, roas
        }

        var kind: Kind
        var name: String
        var points: Double
        var maxPoints: Double
        /// Valor medido, já formatado (ex.: "62 %").
        var detail: String
        /// `false` quando não há dados e o fator ficou neutro.
        var hasData = true

        var id: Kind { kind }
        var ratio: Double { maxPoints > 0 ? points / maxPoints : 0 }
    }

    var score: Int
    var classification: ProductClass
    var factors: [Factor]
    var action: String
}

/// Dá um score de 0 a 100 a cada produto e sugere o que fazer.
nonisolated enum ProductScorer {
    /// Um produto novo fica "em teste" durante este período.
    static let testPeriodDays = 14
    static let winnerThreshold = 70
    static let promisingThreshold = 45
    /// Pontos (em fração) para fatores sem dados: nem premeia nem castiga.
    static let neutralRatio = 0.6

    /// Ordena do melhor para o pior score.
    static func rank(_ products: [ProductPerformance]) -> [(performance: ProductPerformance, score: ProductScore)] {
        let bestUnits = products.map(\.units).max() ?? 0
        let totalRevenue = products.reduce(Decimal(0)) { $0 + $1.revenue }
        return products
            .map { ($0, score($0, bestUnits: bestUnits, totalRevenue: totalRevenue)) }
            .sorted { $0.1.score != $1.1.score ? $0.1.score > $1.1.score : $0.0.title < $1.0.title }
    }

    static func score(_ product: ProductPerformance, bestUnits: Int, totalRevenue: Decimal) -> ProductScore {
        let factors = factors(for: product, bestUnits: bestUnits, totalRevenue: totalRevenue)
        let score = Int(factors.reduce(0) { $0 + $1.points }.rounded())
        let classification = classify(product, score: score)
        return ProductScore(
            score: score,
            classification: classification,
            factors: factors,
            action: action(for: product, classification: classification, factors: factors)
        )
    }

    // MARK: - Fatores

    static func factors(for product: ProductPerformance, bestUnits: Int, totalRevenue: Decimal) -> [ProductScore.Factor] {
        var factors: [ProductScore.Factor] = []

        let salesRatio = bestUnits > 0 ? Double(product.units) / Double(bestUnits) : 0
        factors.append(.init(kind: .sales, name: "Vendas", points: 20 * clamp(salesRatio), maxPoints: 20,
                             detail: "\(product.units) un. em 30 dias"))

        let share = totalRevenue > 0 ? (product.revenue / totalRevenue).doubleValue : 0
        factors.append(.init(kind: .revenue, name: "Receita", points: 15 * clamp(share / 0.25), maxPoints: 15,
                             detail: "\(percent(share)) da receita"))

        if let margin = product.marginRate, product.unitCost > 0 {
            factors.append(.init(kind: .margin, name: "Margem", points: 20 * clamp((margin - 0.2) / 0.5), maxPoints: 20,
                                 detail: percent(margin)))
        } else {
            factors.append(.init(kind: .margin, name: "Margem", points: 20 * neutralRatio, maxPoints: 20,
                                 detail: "Sem custo definido", hasData: false))
        }

        if let conversion = product.checkoutConversion {
            factors.append(.init(kind: .funnel, name: "Funil", points: 10 * clamp((conversion - 0.3) / 0.5), maxPoints: 10,
                                 detail: "\(percent(conversion)) dos checkouts compram"))
        } else {
            factors.append(.init(kind: .funnel, name: "Funil", points: 10 * neutralRatio, maxPoints: 10,
                                 detail: "Poucos dados", hasData: false))
        }

        factors.append(.init(kind: .refunds, name: "Reembolsos", points: 10 * (1 - clamp(product.refundRate / 0.2)), maxPoints: 10,
                             detail: percent(product.refundRate)))

        let recency: Double = switch product.daysSinceLastSale {
        case nil: 0
        case let days?: 1 - clamp(Double(days - 3) / 27)
        }
        factors.append(.init(kind: .recency, name: "Recência", points: 15 * recency, maxPoints: 15,
                             detail: product.daysSinceLastSale.map { $0 == 0 ? "Vendeu hoje" : "Há \($0) dias" } ?? "Sem vendas"))

        if let roas = product.roas {
            factors.append(.init(kind: .roas, name: "ROAS", points: 10 * clamp((roas - 1) / 3), maxPoints: 10,
                                 detail: roas.formatted(.number.precision(.fractionLength(1)).locale(.app)) + "×"))
        } else {
            factors.append(.init(kind: .roas, name: "ROAS", points: 10 * 0.7, maxPoints: 10,
                                 detail: "Sem anúncios", hasData: false))
        }

        return factors
    }

    // MARK: - Classificação e ação

    static func classify(_ product: ProductPerformance, score: Int) -> ProductClass {
        if product.ageDays < testPeriodDays { return .testing }
        if product.orderedUnits < 3, product.ageDays < 30 { return .testing }
        if score >= winnerThreshold { return .winner }
        if score >= promisingThreshold { return .promising }
        return .loser
    }

    static func action(for product: ProductPerformance, classification: ProductClass, factors: [ProductScore.Factor]) -> String {
        switch classification {
        case .winner:
            if let days = product.daysOfStock, days < 14 {
                return "Repor stock: ao ritmo atual só dá para \(days) dias."
            }
            if let roas = product.roas, roas >= 3 {
                return "Escalar: aumentar o orçamento de anúncios."
            }
            return "Escalar: testar anúncios e novos criativos."

        case .promising:
            let weakest = factors.filter(\.hasData).min { $0.ratio < $1.ratio }
            return switch weakest?.kind {
            case .margin: "Rever o preço ou o fornecedor para subir a margem."
            case .funnel: "Melhorar a página do produto: fotos, descrição e avaliações."
            case .refunds: "Perceber o motivo das devoluções (qualidade, tamanho, descrição)."
            case .roas: "Ajustar os anúncios: público ou criativo."
            case .recency: "Reativar com uma promoção ou um e-mail."
            case .sales, .revenue, nil: "Dar mais visibilidade: destaque na loja e anúncios."
            }

        case .testing:
            let remaining = max(0, testPeriodDays - product.ageDays)
            return remaining > 0
                ? "Manter o teste mais \(remaining) dias antes de decidir."
                : "Juntar mais dados (vendas ou anúncios) antes de decidir."

        case .loser:
            if product.adSpend > 0 {
                return "Pausar os anúncios e tirar de destaque."
            }
            if (product.daysSinceLastSale ?? .max) >= 30 {
                return "Arquivar ou escoar o stock com desconto."
            }
            return "Rever a oferta (preço, fotos) ou descontinuar."
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)).locale(.app))
    }
}
