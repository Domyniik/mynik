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
    /// De onde veio a categoria sugerida; `nil` se foi escolhida à mão.
    @State private var suggestionSource: CategorySuggestionSource?
    /// O utilizador escolheu a categoria: deixa de haver sugestões.
    @State private var isCategoryChosenByUser = false

    init(transaction: FinanceTransaction? = nil) {
        self.transaction = transaction
        _draft = State(initialValue: transaction.map(TransactionDraft.init) ?? TransactionDraft())
    }

    /// Movimento novo já preenchido (ex.: vindo do scanner de faturas).
    init(prefill: TransactionDraft) {
        self.transaction = nil
        _draft = State(initialValue: prefill)
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
                        .keyboardType(.decimalPad)

                    Picker("Moeda", selection: $draft.currencyCode) {
                        ForEach(Currency.supportedCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }

                    DatePicker("Data", selection: $draft.date, displayedComponents: .date)
                }

                Section {
                    Picker("Categoria", selection: categorySelection) {
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
                } footer: {
                    if let suggestionSource, draft.category != nil {
                        Label(suggestionSource.label, systemImage: suggestionSource.symbolName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notas") {
                    TextField("Notas", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let linked = transaction?.linkedNotes, !linked.isEmpty {
                    Section {
                        ForEach(linked) { note in
                            Label { Text(note.displayTitle) } icon: { Text(note.icon) }
                        }
                    } header: {
                        Text("Páginas ligadas")
                    } footer: {
                        Text("As ligações gerem-se no editor de notas.")
                    }
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
            .task(id: SuggestionKey(title: draft.title, kind: draft.kind)) {
                await suggestCategory()
            }
            .onAppear {
                if transaction == nil, draft.account == nil {
                    draft.account = accounts.first
                }
            }
            .alert("Não foi possível guardar", isPresented: $isShowingSaveError) { }
        }
    }

    /// Escolha manual da categoria (desliga as sugestões).
    private var categorySelection: Binding<Category?> {
        Binding {
            draft.category
        } set: { category in
            draft.category = category
            isCategoryChosenByUser = true
            suggestionSource = nil
        }
    }

    /// Sugere a categoria enquanto se escreve a descrição de um movimento novo.
    private func suggestCategory() async {
        guard transaction == nil, !isCategoryChosenByUser, CategorizationService.isEnabled else { return }
        // Espera que o utilizador pare de escrever.
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        let result = await CategorizationService.suggest(title: draft.title, kind: draft.kind, in: modelContext)
        guard !Task.isCancelled, !isCategoryChosenByUser, let result else { return }
        draft.category = result.category
        suggestionSource = result.source
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

/// Muda quando a descrição ou o tipo mudam (recomeça a sugestão).
private struct SuggestionKey: Equatable {
    let title: String
    let kind: TransactionKind
}

#Preview(traits: .sampleData) {
    TransactionFormView()
}
