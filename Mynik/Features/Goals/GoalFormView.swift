import SwiftData
import SwiftUI

/// Formulário para criar ou editar uma meta.
struct GoalFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    private let goal: Goal?
    @State private var draft: GoalDraft
    @State private var isShowingSaveError = false

    init(goal: Goal? = nil) {
        self.goal = goal
        _draft = State(initialValue: goal.map(GoalDraft.init) ?? GoalDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome da meta", text: $draft.title)
                    LabeledContent("Valor-alvo") {
                        amountField("Valor-alvo", value: $draft.targetAmount)
                    }
                    Picker("Moeda", selection: $draft.currencyCode) {
                        ForEach(Currency.supportedCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    Toggle("Tem prazo", isOn: $draft.hasDeadline.animation())
                    if draft.hasDeadline {
                        DatePicker("Prazo", selection: $draft.deadline, displayedComponents: .date)
                    }
                }

                Section {
                    Picker("Progresso", selection: $draft.source.animation()) {
                        ForEach(GoalSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    sourceFields
                } header: {
                    Text("Ligação às Finanças")
                } footer: {
                    Text(draft.source.explanation)
                }

                Section("Cor") {
                    ColorChoicePicker(selection: $draft.color)
                }

                Section("Ícone") {
                    SymbolChoicePicker(symbols: GoalDraft.symbols, tint: draft.color.color, selection: $draft.symbolName)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(goal == nil ? "Nova meta" : "Editar meta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .alert("Não foi possível guardar", isPresented: $isShowingSaveError) { }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 600)
        #endif
    }

    @ViewBuilder
    private var sourceFields: some View {
        switch draft.source {
        case .manual:
            LabeledContent("Já juntei") {
                amountField("Já juntei", value: $draft.manualAmount)
            }
        case .account:
            Picker("Conta", selection: $draft.account) {
                Text("Escolher…").tag(Account?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(Optional(account))
                }
            }
        case .category:
            Picker("Categoria", selection: $draft.category) {
                Text("Escolher…").tag(Category?.none)
                ForEach(categories) { category in
                    Label(category.name, systemImage: category.symbolName).tag(Optional(category))
                }
            }
            DatePicker("Conta a partir de", selection: $draft.startDate, displayedComponents: .date)
        }
    }

    private func amountField(_ title: String, value: Binding<Decimal>) -> some View {
        TextField(title, value: value, format: .currency(code: draft.currencyCode))
            .multilineTextAlignment(.trailing)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
    }

    private func save() {
        if let goal {
            draft.apply(to: goal)
        } else {
            modelContext.insert(draft.makeGoal())
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
    GoalFormView()
}
