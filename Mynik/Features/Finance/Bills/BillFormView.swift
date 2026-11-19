import SwiftData
import SwiftUI

/// Formulário para adicionar ou editar uma conta a pagar.
struct BillFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    private let bill: Bill?
    @State private var draft: BillDraft
    @State private var isShowingSaveError = false

    init(bill: Bill? = nil) {
        self.bill = bill
        _draft = State(initialValue: bill.map(BillDraft.init) ?? BillDraft())
    }

    private var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Descrição", text: $draft.title)

                    TextField("Valor", value: $draft.amount, format: .currency(code: draft.currencyCode))
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif

                    Picker("Moeda", selection: $draft.currencyCode) {
                        ForEach(Currency.supportedCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section {
                    DatePicker("Vencimento", selection: $draft.dueDate, displayedComponents: .date)

                    Picker("Repete", selection: $draft.recurrence) {
                        ForEach(BillRecurrence.allCases) { recurrence in
                            Text(recurrence.title).tag(recurrence)
                        }
                    }
                }

                Section {
                    Picker("Categoria", selection: $draft.category) {
                        Text("Sem categoria").tag(Category?.none)
                        ForEach(expenseCategories) { category in
                            Label(category.name, systemImage: category.symbolName)
                                .tag(Optional(category))
                        }
                    }

                    Picker("Conta", selection: $draft.account) {
                        Text("Sem conta").tag(Account?.none)
                        ForEach(accounts) { account in
                            Text(account.name).tag(Optional(account))
                        }
                    }
                }

                Section("Notas") {
                    TextField("Notas", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(bill == nil ? "Nova conta" : "Editar conta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onAppear {
                if bill == nil, draft.account == nil {
                    draft.account = accounts.first
                }
            }
            .alert("Não foi possível guardar", isPresented: $isShowingSaveError) { }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    private func save() {
        if let bill {
            draft.apply(to: bill)
        } else {
            modelContext.insert(draft.makeBill())
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            isShowingSaveError = true
        }
    }
}

#Preview(traits: .sampleData) {
    BillFormView()
}
