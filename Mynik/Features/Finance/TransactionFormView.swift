import SwiftData
import SwiftUI

/// Formulário para adicionar ou editar um gasto/receita.
struct TransactionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    private let transaction: FinanceTransaction?
    @State private var draft: TransactionDraft
    @State private var isShowingSaveError = false

    init(transaction: FinanceTransaction? = nil) {
        self.transaction = transaction
        _draft = State(initialValue: transaction.map(TransactionDraft.init) ?? TransactionDraft())
    }

    private var categoriesForKind: [Category] {
        categories.filter { $0.kind == draft.kind }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $draft.kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

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

                    DatePicker("Data", selection: $draft.date, displayedComponents: .date)
                }

                Section {
                    Picker("Categoria", selection: $draft.category) {
                        Text("Sem categoria").tag(Category?.none)
                        ForEach(categoriesForKind) { category in
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
            .navigationTitle(transaction == nil ? "Novo movimento" : "Editar movimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onChange(of: draft.kind) {
                if draft.category?.kind != draft.kind {
                    draft.category = nil
                }
            }
            .onAppear {
                if transaction == nil, draft.account == nil {
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
        if let transaction {
            draft.apply(to: transaction)
        } else {
            modelContext.insert(draft.makeTransaction())
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
    TransactionFormView()
}
