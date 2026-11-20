import SwiftData
import SwiftUI

/// Resumo do dia: saldo do mês, contas a vencer, tarefas, metas, loja e últimos gastos.
struct TodayView: View {
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]

    @State private var isAddingTransaction = false

    private var recentTransactions: ArraySlice<FinanceTransaction> {
        transactions.prefix(5)
    }

    var body: some View {
        List {
            Section {
                MonthSummaryCard(summary: MonthSummary(month: .now, transactions: transactions, converter: converter))
            }

            UpcomingBillsSection(days: 7)

            TodayTasksSection()

            TodayGoalsSection()

            TodayStoreSection()

            Section("Últimos movimentos") {
                if recentTransactions.isEmpty {
                    Text("Ainda não há movimentos.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .navigationTitle("Hoje")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Adicionar movimento", systemImage: "plus") {
                    isAddingTransaction = true
                }
            }
        }
        .sheet(isPresented: $isAddingTransaction) {
            TransactionFormView()
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        TodayView()
    }
}
