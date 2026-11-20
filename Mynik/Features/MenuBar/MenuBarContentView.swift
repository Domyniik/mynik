#if os(macOS)
import SwiftData
import SwiftUI

/// Painel da barra de menus do Mac: saldo do mês, contas a vencer e gasto rápido.
struct MenuBarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.brlPerEUR) private var brlPerEUR = CurrencyConverter.defaultBRLPerEUR

    @Query private var monthTransactions: [FinanceTransaction]
    @Query private var upcomingBills: [Bill]

    init(now: Date = .now, calendar: Calendar = .current) {
        let month = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        let start = month.start
        let end = month.end
        _monthTransactions = Query(filter: #Predicate<FinanceTransaction> { $0.date >= start && $0.date < end })
        let limit = calendar.date(byAdding: .day, value: 8, to: calendar.startOfDay(for: now)) ?? now
        _upcomingBills = Query(filter: #Predicate<Bill> { !$0.isPaid && $0.dueDate < limit }, sort: \Bill.dueDate)
    }

    private var summary: MonthSummary {
        MonthSummary(month: .now, transactions: monthTransactions, converter: CurrencyConverter(storedRate: brlPerEUR))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonthSummaryCard(summary: summary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Contas a vencer")
                    .font(.headline)
                if upcomingBills.isEmpty {
                    Label("Nada a pagar nos próximos 7 dias", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcomingBills.prefix(4)) { bill in
                        BillRow(bill: bill) { pay(bill) }
                    }
                }
            }

            Divider()

            MenuBarQuickExpenseView()

            Divider()

            HStack {
                Button("Abrir o Mynik", systemImage: "macwindow") {
                    openWindow(id: MynikApp.mainWindowID)
                    NSApplication.shared.activate()
                }
                Spacer()
                Button("Sair", systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .frame(width: 340)
        .environment(\.locale, .app)
    }

    private func pay(_ bill: Bill) {
        BillPaymentService.markPaid(bill, in: modelContext)
        try? modelContext.save()
        IntentSideEffects.dataChanged(in: modelContext)
    }
}

/// "Gastei X em Y" sem abrir a janela.
struct MenuBarQuickExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var amount: Decimal?
    @State private var categoryUID = ""
    @State private var note = ""
    @State private var confirmation: String?

    private var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gasto rápido")
                .font(.headline)
            HStack {
                TextField("Valor", value: $amount, format: .number.precision(.fractionLength(0...2)).locale(.app))
                    .frame(width: 80)
                Picker("Categoria", selection: $categoryUID) {
                    Text("Sem categoria").tag("")
                    ForEach(expenseCategories) { category in
                        Label(category.name, systemImage: category.symbolName).tag(category.uid)
                    }
                }
                .labelsHidden()
            }
            HStack {
                TextField("Descrição (opcional)", text: $note)
                    .onSubmit(add)
                Button("Registar", action: add)
                    .buttonStyle(.glassProminent)
                    .disabled((amount ?? 0) <= 0)
                    .keyboardShortcut(.defaultAction)
            }
            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .textFieldStyle(.roundedBorder)
        .onAppear {
            if categoryUID.isEmpty {
                categoryUID = expenseCategories.first?.uid ?? ""
            }
        }
    }

    private func add() {
        guard let amount, amount > 0 else { return }
        let category = expenseCategories.first { $0.uid == categoryUID }
        do {
            let transaction = try QuickEntryService.addExpense(amount: amount, category: category, title: note, in: modelContext)
            IntentSideEffects.dataChanged(in: modelContext)
            confirmation = "Registei \(Currency.format(transaction.amount)) em \(transaction.title)."
            self.amount = nil
            note = ""
        } catch {
            confirmation = nil
        }
    }
}
#endif
