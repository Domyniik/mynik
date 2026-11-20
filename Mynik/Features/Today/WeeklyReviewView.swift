import SwiftData
import SwiftUI

/// Revisão semanal: o que aconteceu de segunda a domingo e o que vem a seguir.
struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter
    // Recalcula sempre que os movimentos mudam.
    @Query private var transactions: [FinanceTransaction]

    var body: some View {
        let review = WeeklyReview(context: modelContext, converter: converter)
        List {
            Section {
                LabeledContent("Gastos", value: Currency.format(review.expenses))
                if let change = review.expenseChange {
                    LabeledContent("Face à semana anterior") {
                        Text(change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()).locale(.app)))
                            .foregroundStyle(change > 0 ? .red : .green)
                    }
                }
                LabeledContent("Receitas", value: Currency.format(review.income))
                ForEach(review.topCategories, id: \.name) { line in
                    LabeledContent(line.name, value: Currency.format(line.amount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Dinheiro")
            } footer: {
                Text(review.week.start.formatted(.dateTime.day().month(.wide).locale(.app)) + " – "
                    + review.week.end.addingTimeInterval(-1).formatted(.dateTime.day().month(.wide).locale(.app)))
            }

            Section("Contas") {
                LabeledContent("Pagas esta semana", value: "\(review.billsPaid)")
                LabeledContent(
                    "A vencer na próxima semana",
                    value: review.billsNextWeek == 0 ? "nenhuma" : "\(review.billsNextWeek) · \(Currency.format(review.billsNextWeekTotal))"
                )
            }

            Section("Produtividade") {
                LabeledContent("Tarefas concluídas", value: "\(review.tasksCompleted)")
                if !review.habits.isEmpty {
                    LabeledContent("Hábitos no objetivo", value: "\(review.habitsOnTrack) de \(review.habits.count)")
                    ForEach(review.habits, id: \.name) { habit in
                        LabeledContent(habit.name, value: "\(habit.done)/\(habit.target)")
                            .font(.subheadline)
                            .foregroundStyle(habit.done >= habit.target ? .green : .secondary)
                    }
                }
            }

            if review.storeOrders > 0 {
                Section("Loja") {
                    LabeledContent("Vendas", value: Currency.format(review.storeSales))
                    LabeledContent("Pedidos", value: "\(review.storeOrders)")
                }
            }
        }
        .navigationTitle("Revisão semanal")
    }
}

/// Cartão de domingo na tela Hoje.
struct WeeklyReviewCard: View {
    var body: some View {
        if WeeklyReview.isReviewDay() {
            Section {
                NavigationLink {
                    WeeklyReviewView()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Revisão da semana").font(.headline)
                            Text("É domingo: vê como correu a semana e prepara a próxima.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack { WeeklyReviewView() }
}
