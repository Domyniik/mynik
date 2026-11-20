import Foundation

/// Decisão sobre um produto no fim do teste.
nonisolated enum ProductDecision: String, CaseIterable, Identifiable, Sendable {
    case scale
    case keep
    case discontinue

    var id: Self { self }

    var title: String {
        switch self {
        case .scale: "Escalar"
        case .keep: "Manter"
        case .discontinue: "Descontinuar"
        }
    }

    /// Estado depois da decisão.
    var stateTitle: String {
        switch self {
        case .scale: "A escalar"
        case .keep: "Mantido"
        case .discontinue: "Descontinuado"
        }
    }

    var symbolName: String {
        switch self {
        case .scale: "arrow.up.forward.circle"
        case .keep: "pause.circle"
        case .discontinue: "xmark.circle"
        }
    }
}

/// Ciclo de vida de um produto: teste → decisão → escalar / manter / descontinuar.
nonisolated enum ProductLifecycle {
    enum Phase: Equatable, Sendable {
        /// Ainda dentro do período de teste.
        case testing(daysLeft: Int)
        /// O teste acabou e falta decidir (`suggested` é `nil` se os dados não chegam).
        case awaitingDecision(suggested: ProductDecision?)
        case decided(ProductDecision)

        var title: String {
            switch self {
            case .testing: "Em teste"
            case .awaitingDecision: "Decisão pendente"
            case .decided(let decision): decision.stateTitle
            }
        }

        /// Ordem nas listas: o que pede ação primeiro.
        var sortOrder: Int {
            switch self {
            case .awaitingDecision: 0
            case .testing: 1
            case .decided(.scale): 2
            case .decided(.keep): 3
            case .decided(.discontinue): 4
            }
        }
    }

    static func phase(ageDays: Int, decision: ProductDecision?, classification: ProductClass) -> Phase {
        if let decision { return .decided(decision) }
        if ageDays < ProductScorer.testPeriodDays {
            return .testing(daysLeft: ProductScorer.testPeriodDays - ageDays)
        }
        return .awaitingDecision(suggested: suggestedDecision(for: classification))
    }

    /// O que o ranking sugere decidir (`nil` = prolongar o teste).
    static func suggestedDecision(for classification: ProductClass) -> ProductDecision? {
        switch classification {
        case .winner: .scale
        case .promising: .keep
        case .loser: .discontinue
        case .testing: nil
        }
    }

    /// Aviso quando os números já não batem com a decisão tomada.
    static func reviewWarning(decision: ProductDecision?, classification: ProductClass, isActiveInShop: Bool) -> String? {
        switch (decision, classification) {
        case (.scale?, .loser):
            "Está a escalar mas agora é perdedor: rever os anúncios."
        case (.keep?, .loser):
            "Desceu para perdedor desde a decisão: considera descontinuar."
        case (.discontinue?, .winner):
            "Foi descontinuado mas continua a vender bem: rever a decisão."
        case (.discontinue?, _) where isActiveInShop:
            "Descontinuado no Mynik mas ainda ativo na Shopify: arquiva-o na loja."
        default:
            nil
        }
    }
}
