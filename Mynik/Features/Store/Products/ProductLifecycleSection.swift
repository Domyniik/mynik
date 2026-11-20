import SwiftUI

/// Ciclo de vida na ficha do produto: fase, sugestão e decisão.
struct ProductLifecycleSection: View {
    @Bindable var product: StoreProduct
    let performance: ProductPerformance
    let score: ProductScore

    private var phase: ProductLifecycle.Phase {
        ProductLifecycle.phase(ageDays: performance.ageDays, decision: product.decision, classification: score.classification)
    }

    var body: some View {
        Section {
            ProductLifecycleTimeline(phase: phase)
                .padding(.vertical, 4)

            Text(phaseDescription)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let warning = ProductLifecycle.reviewWarning(
                decision: product.decision,
                classification: score.classification,
                isActiveInShop: product.isActive
            ) {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            decisionButtons

            if product.decision != nil {
                TextField("Nota (porquê, próximos passos)", text: $product.decisionNote, axis: .vertical)
                    .lineLimit(1...4)
                Button("Desfazer decisão", systemImage: "arrow.uturn.backward", role: .destructive) {
                    product.decision = nil
                }
                .font(.callout)
            }
        } header: {
            Text("Ciclo de vida")
        }
    }

    private var phaseDescription: String {
        switch phase {
        case .testing(let daysLeft):
            let start = product.createdAt.formatted(.dateTime.day().month(.wide).locale(.app))
            return "Em teste desde \(start). Faltam \(daysLeft) dias para decidir."
        case .awaitingDecision(let suggested):
            if let suggested {
                return "O teste acabou. O ranking sugere: \(suggested.title)."
            }
            return "O teste acabou mas há poucos dados. Prolonga o teste (mais anúncios ou visibilidade) antes de decidir."
        case .decided(let decision):
            let date = product.decidedAt?.formatted(.dateTime.day().month(.wide).year().locale(.app)) ?? "—"
            return "\(decision.stateTitle) desde \(date)."
        }
    }

    private var suggested: ProductDecision? {
        if case .awaitingDecision(let suggested) = phase { return suggested }
        return nil
    }

    private var decisionButtons: some View {
        HStack {
            ForEach(ProductDecision.allCases) { decision in
                let isCurrent = product.decision == decision
                Button {
                    product.decision = decision
                } label: {
                    Label(decision.title, systemImage: decision.symbolName)
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(isCurrent || suggested == decision ? .accentColor : .secondary)
                .disabled(isCurrent)
                .accessibilityHint(suggested == decision ? "Sugerido pelo ranking" : "")
            }
        }
    }
}

/// Teste → Decisão → Resultado, com a fase atual destacada.
struct ProductLifecycleTimeline: View {
    let phase: ProductLifecycle.Phase

    private var step: Int {
        switch phase {
        case .testing: 0
        case .awaitingDecision: 1
        case .decided: 2
        }
    }

    private var labels: [String] {
        let result = if case .decided(let decision) = phase { decision.stateTitle } else { "Resultado" }
        return ["Teste", "Decisão", result]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    Circle()
                        .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .overlay {
                            if index == step {
                                Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 5)
                            }
                        }
                    Text(labels[index])
                        .font(.caption)
                        .foregroundStyle(index == step ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    if index < labels.count - 1 {
                        Rectangle()
                            .fill(index < step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .offset(y: 6)
                            .padding(.leading, 30)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(x: 40)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fase: \(phase.title)")
    }
}
