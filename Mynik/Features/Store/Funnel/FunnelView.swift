import SwiftData
import SwiftUI

/// Funil da loja (visitas → carrinho → checkout → compra) e o diagnóstico.
struct FunnelView: View {
    @Query(sort: \DailyStat.date) private var stats: [DailyStat]
    @State private var days = 30

    var body: some View {
        let diagnosis = FunnelDiagnosis.diagnose(stats: stats, days: days)

        List {
            Section {
                Picker("Período", selection: $days) {
                    Text("7 dias").tag(7)
                    Text("30 dias").tag(30)
                }
                .pickerStyle(.segmented)
            }

            Section {
                FunnelDiagnosisCard(problem: diagnosis.problem)
            }

            if diagnosis.problem != .noTrafficData {
                Section {
                    ForEach(diagnosis.stages) { stage in
                        FunnelStageRow(stage: stage, total: diagnosis.stages.first?.count ?? 0)
                    }
                } header: {
                    Text("Etapas")
                } footer: {
                    Text(footer(diagnosis))
                }
            }
        }
        .navigationTitle("Funil")
    }

    private func footer(_ diagnosis: FunnelDiagnosis) -> String {
        let perDay = diagnosis.sessionsPerDay.formatted(.number.precision(.fractionLength(0)).locale(.app))
        let conversion = diagnosis.conversionRate.map { $0.formatted(.percent.precision(.fractionLength(1)).locale(.app)) } ?? "—"
        return "\(perDay) visitas por dia · conversão \(conversion). Referências: carrinho ≥ 6 %, checkout e compra ≥ 50 %."
    }
}

/// Cartão com o problema principal e o que fazer.
struct FunnelDiagnosisCard: View {
    let problem: FunnelProblem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(problem.title, systemImage: problem.symbolName)
                .font(.headline)
                .foregroundStyle(color)
            Text(problem.explanation)
                .font(.callout)
            if !problem.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(problem.suggestions, id: \.self) { suggestion in
                        Label(suggestion, systemImage: "arrow.right.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var color: Color {
        switch problem {
        case .healthy: .green
        case .notEnoughData, .noTrafficData: .secondary
        case .traffic: .blue
        case .pagePrice, .checkoutShipping: .orange
        }
    }
}

/// Uma etapa: barra proporcional às visitas e taxa face à etapa anterior.
private struct FunnelStageRow: View {
    let stage: FunnelStage
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stage.name).font(.headline)
                Spacer()
                Text(stage.count.formatted()).monospacedDigit()
                if let rate = stage.rate {
                    Text(rate.formatted(.percent.precision(.fractionLength(1)).locale(.app)))
                        .monospacedDigit()
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .frame(minWidth: 56, alignment: .trailing)
                }
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(statusColor.opacity(0.7))
                    .frame(width: max(4, proxy.size.width * fraction))
            }
            .frame(height: 8)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var fraction: Double {
        total > 0 ? min(1, Double(stage.count) / Double(total)) : 0
    }

    private var statusColor: Color {
        switch stage.status {
        case .good: .green
        case .ok: .yellow
        case .weak: .red
        case .none: .accentColor
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        FunnelView()
    }
}
