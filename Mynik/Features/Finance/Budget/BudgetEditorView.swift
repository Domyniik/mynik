import SwiftData
import SwiftUI

/// Define (ou remove) o orçamento mensal de uma categoria.
struct BudgetEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let category: Category
    @State private var amount: Decimal

    init(category: Category) {
        self.category = category
        _amount = State(initialValue: category.monthlyBudget)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        TextField("Orçamento", value: $amount, format: .currency(code: Currency.defaultCode))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    } label: {
                        Label(category.name, systemImage: category.symbolName)
                    }
                } footer: {
                    Text("Limite mensal em euros. Deixa a 0 para não ter orçamento.")
                }

                if category.monthlyBudget > 0 {
                    Section {
                        Button("Remover orçamento", role: .destructive) {
                            amount = 0
                            save()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Orçamento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(amount < 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        category.monthlyBudget = max(amount, 0)
        try? modelContext.save()
        dismiss()
    }
}
