import SwiftData
import SwiftUI

/// Resumo do dia: saldo do mês, contas e prazos a vencer, tarefas, metas, loja e últimos gastos.
struct TodayView: View {
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]

    @State private var isAddingTransaction = false
    @State private var isAskingMynik = false

    private var recentTransactions: ArraySlice<FinanceTransaction> {
        transactions.prefix(5)
    }

    var body: some View {
        List {
            Section {
                MonthSummaryCard(summary: MonthSummary(month: .now, transactions: transactions, converter: converter))
            }

            UpcomingBillsSection(days: 7)

            TodayCalendarSection()

            TodayAgendaSection()

            TodayTasksSection()

            TodayHabitsSection()

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
            ToolbarItem(placement: .secondaryAction) {
                Button("Pergunte ao Mynik", systemImage: "sparkles") {
                    isAskingMynik = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Adicionar movimento", systemImage: "plus") {
                    isAddingTransaction = true
                }
            }
        }
        .sheet(isPresented: $isAddingTransaction) {
            TransactionFormView()
        }
        .sheet(isPresented: $isAskingMynik) {
            NavigationStack {
                AskMynikView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fechar", systemImage: "xmark") { isAskingMynik = false }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 560)
            #endif
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        TodayView()
    }
}
