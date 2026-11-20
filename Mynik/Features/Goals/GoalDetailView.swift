import SwiftData
import SwiftUI

/// Detalhe de uma meta: progresso, quanto falta, ritmo mensal e movimentos.
struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter

    let goal: Goal

    @State private var isEditing = false
    @State private var isContributing = false

    var body: some View {
        let progress = GoalProgress(goal: goal, converter: converter)
        List {
            Section {
                VStack(spacing: 12) {
                    Gauge(value: progress.fraction) {
                        Image(systemName: goal.symbolName)
                    } currentValueLabel: {
                        Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(goal.color.color)
                    .scaleEffect(1.6)
                    .frame(height: 110)

                    Text(Currency.format(progress.current, code: goal.currencyCode))
                        .font(.title.bold())
                        .monospacedDigit()
                    Text("de \(Currency.format(progress.target, code: goal.currencyCode))")
                        .foregroundStyle(.secondary)

                    if GoalContributionService.acceptsContributions(goal), !progress.isReached {
                        Button("Juntar dinheiro", systemImage: "plus") { isContributing = true }
                            .buttonStyle(.borderedProminent)
                            .tint(goal.color.color)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                LabeledContent("Falta", value: Currency.format(progress.remaining, code: goal.currencyCode))
                if let deadline = goal.deadline {
                    LabeledContent("Prazo", value: deadline.formatted(.dateTime.day().month(.wide).year()))
                }
                if let monthly = progress.monthlyNeeded {
                    LabeledContent("Juntar por mês", value: Currency.format(monthly, code: goal.currencyCode))
                }
                if progress.isPastDeadline, !progress.isReached {
                    Label("O prazo já passou", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                LabeledContent("Progresso", value: sourceDescription)
            }

            let contributions = GoalProgress.contributions(for: goal)
            if !contributions.isEmpty {
                Section("Movimentos") {
                    ForEach(contributions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .navigationTitle(goal.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar", systemImage: "pencil") { isEditing = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(goal.isArchived ? "Reativar" : "Arquivar", systemImage: goal.isArchived ? "tray.and.arrow.up" : "archivebox") {
                    goal.isArchived.toggle()
                    try? modelContext.save()
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            GoalFormView(goal: goal)
        }
        .sheet(isPresented: $isContributing) {
            GoalContributionSheet(goal: goal)
        }
    }

    private var sourceDescription: String {
        switch goal.source {
        case .manual: "Manual"
        case .account: "Saldo de \(goal.account?.name ?? "—")"
        case .category: "\(goal.category?.name ?? "—") desde \(goal.startDate.formatted(.dateTime.day().month(.abbreviated)))"
        }
    }
}
