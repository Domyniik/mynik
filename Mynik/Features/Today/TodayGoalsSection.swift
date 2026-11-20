import SwiftData
import SwiftUI

/// Metas ativas por atingir (as de prazo mais próximo primeiro), na tela Hoje.
struct TodayGoalsSection: View {
    @Environment(\.currencyConverter) private var converter
    @Query(filter: #Predicate<Goal> { !$0.isArchived }) private var goals: [Goal]

    var body: some View {
        let pending = goals
            .filter { !GoalProgress(goal: $0, converter: converter).isReached }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
        if !pending.isEmpty {
            DashboardCard("Metas", systemImage: "target") {
                CardRows(Array(pending.prefix(3))) { goal in
                    GoalRow(goal: goal)
                }
            }
        }
    }
}
