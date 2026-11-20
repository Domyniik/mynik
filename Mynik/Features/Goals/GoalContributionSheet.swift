import SwiftData
import SwiftUI

/// Regista um valor juntado para uma meta.
struct GoalContributionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    let goal: Goal

    @State private var amount: Decimal = 0
    @State private var date = Date.now
    @State private var account: Account?
    @State private var isShowingSaveError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Valor", value: $amount, format: .currency(code: goal.currencyCode))
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    if goal.source == .category {
                        DatePicker("Data", selection: $date, displayedComponents: .date)
                        Picker("Conta", selection: $account) {
                            Text("Sem conta").tag(Account?.none)
                            ForEach(accounts) { account in
                                Text(account.name).tag(Optional(account))
                            }
                        }
                    }
                } footer: {
                    if goal.source == .category, let category = goal.category {
                        Text("Cria um movimento em \(category.name) nas Finanças.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Juntar para \(goal.title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(amount <= 0)
                }
            }
            .onAppear { account = account ?? accounts.first }
            .alert("Não foi possível guardar", isPresented: $isShowingSaveError) { }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 260)
        #endif
    }

    private func save() {
        GoalContributionService.contribute(amount, to: goal, account: account, date: date, in: modelContext)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            isShowingSaveError = true
        }
    }
}
