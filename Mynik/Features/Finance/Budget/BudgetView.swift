import SwiftData
import SwiftUI

/// Orçamento mensal por categoria: quanto já foi gasto e quanto falta.
struct BudgetView: View {
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var transactions: [FinanceTransaction]

    @State private var month = Date.now
    @State private var editingCategory: Category?

    private var overview: BudgetOverview {
        BudgetOverview(month: month, categories: categories, transactions: transactions, converter: converter)
    }

    var body: some View {
        let overview = overview

        List {
            Section {
                MonthStepper(month: $month)
            }

            if overview.budgeted.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Sem orçamentos",
                        systemImage: "chart.pie",
                        description: Text("Toca numa categoria para definir quanto queres gastar por mês.")
                    )
                }
            } else {
                Section {
                    BudgetTotalCard(spent: overview.totalSpentInBudgeted, budget: overview.totalBudget)
                }

                Section("Com orçamento") {
                    ForEach(overview.budgeted) { line in
                        lineButton(line)
                    }
                }
            }

            Section("Sem orçamento") {
                ForEach(overview.unbudgeted) { line in
                    lineButton(line)
                }
            }
        }
        .navigationTitle("Orçamento")
        .sheet(item: $editingCategory) { category in
            BudgetEditorView(category: category)
        }
    }

    private func lineButton(_ line: BudgetOverview.Line) -> some View {
        Button {
            editingCategory = line.category
        } label: {
            BudgetLineRow(line: line)
        }
        .buttonStyle(.plain)
    }
}

/// Total gasto vs total orçamentado no mês.
private struct BudgetTotalCard: View {
    let spent: Decimal
    let budget: Decimal

    private var progress: Double {
        budget > 0 ? NSDecimalNumber(decimal: spent / budget).doubleValue : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(spent > budget ? "Acima do orçamento" : "Ainda podes gastar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(Currency.format(abs(budget - spent)))
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(spent > budget ? .red : .primary)

            BudgetBar(progress: progress, tint: .accentColor)

            Text("\(Currency.format(spent)) de \(Currency.format(budget))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        BudgetView()
    }
}
