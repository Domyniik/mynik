import SwiftData
import SwiftUI

/// Lista de metas: ativas e arquivadas.
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \Goal.createdAt) private var goals: [Goal]

    @State private var isAddingGoal = false

    private var active: [Goal] { goals.filter { !$0.isArchived } }
    private var archived: [Goal] { goals.filter(\.isArchived) }

    var body: some View {
        List {
            if goals.isEmpty {
                ContentUnavailableView {
                    Label("Sem metas", systemImage: "target")
                } description: {
                    Text("Define um valor-alvo e liga-o a uma conta ou categoria das Finanças para seguir o progresso.")
                } actions: {
                    Button("Nova meta") { isAddingGoal = true }
                        .buttonStyle(.borderedProminent)
                }
            }

            if !active.isEmpty {
                Section {
                    LabeledContent("Juntado") {
                        Text(Currency.format(totalSaved))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                    LabeledContent("Alvo total") {
                        Text(Currency.format(totalTarget))
                            .monospacedDigit()
                    }
                }

                Section("Ativas") {
                    rows(active)
                }
            }

            if !archived.isEmpty {
                Section("Arquivadas") {
                    rows(archived)
                }
            }
        }
        .navigationTitle("Metas")
        .navigationDestination(for: Goal.self) { goal in
            GoalDetailView(goal: goal)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nova meta", systemImage: "plus") { isAddingGoal = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingGoal) {
            GoalFormView()
        }
    }

    private func rows(_ goals: [Goal]) -> some View {
        ForEach(goals) { goal in
            NavigationLink(value: goal) {
                GoalRow(goal: goal)
            }
            .swipeActions {
                Button("Apagar", systemImage: "trash", role: .destructive) { delete(goal) }
            }
            .contextMenu {
                Button(goal.isArchived ? "Reativar" : "Arquivar", systemImage: "archivebox") {
                    goal.isArchived.toggle()
                    try? modelContext.save()
                }
                Button("Apagar", systemImage: "trash", role: .destructive) { delete(goal) }
            }
        }
    }

    /// Totais das metas ativas, na moeda principal.
    private var totalSaved: Decimal {
        active.reduce(0) { total, goal in
            let saved = min(GoalProgress.savedAmount(for: goal, converter: converter), goal.targetAmount)
            return total + converter.convert(max(0, saved), from: goal.currencyCode)
        }
    }

    private var totalTarget: Decimal {
        active.reduce(0) { $0 + converter.convert($1.targetAmount, from: $1.currencyCode) }
    }

    private func delete(_ goal: Goal) {
        withAnimation {
            modelContext.delete(goal)
            try? modelContext.save()
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        GoalsView()
    }
}
