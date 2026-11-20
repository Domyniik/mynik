import SwiftData
import SwiftUI

/// Lista de gastos e receitas, agrupada por mês.
struct FinanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]

    @State private var isAddingTransaction = false
    @State private var editingTransaction: FinanceTransaction?

    var body: some View {
        List {
            if !transactions.isEmpty {
                Section {
                    MonthSummaryCard(summary: MonthSummary(month: .now, transactions: transactions, converter: converter))
                }
            }

            Section {
                ForEach(FinanceRoute.allCases) { route in
                    NavigationLink(value: route) {
                        Label(route.title, systemImage: route.symbolName)
                    }
                }
            }

            if transactions.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Sem movimentos", systemImage: "eurosign.circle")
                    } description: {
                        Text("Regista o teu primeiro gasto ou receita, ou importa o extrato do banco.")
                    } actions: {
                        Button("Adicionar movimento") {
                            isAddingTransaction = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            ForEach(TransactionMonthGroup.group(transactions)) { group in
                Section(group.title) {
                    ForEach(group.transactions) { transaction in
                        Button {
                            editingTransaction = transaction
                        } label: {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Apagar", systemImage: "trash", role: .destructive) {
                                delete(transaction)
                            }
                        }
                        .contextMenu {
                            Button("Editar", systemImage: "pencil") {
                                editingTransaction = transaction
                            }
                            Button("Apagar", systemImage: "trash", role: .destructive) {
                                delete(transaction)
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: FinanceRoute.self) { route in
            FinanceRouteDestination(route: route)
        }
        .navigationTitle("Finanças")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ReceiptScanButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Adicionar", systemImage: "plus") {
                    isAddingTransaction = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingTransaction) {
            TransactionFormView()
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionFormView(transaction: transaction)
        }
    }

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        FinanceView()
    }
}
