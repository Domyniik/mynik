import AppIntents
import SwiftData

/// "Gastei 12 € em Alimentação" — pela Siri, pelos Atalhos ou pelo Spotlight.
struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Registar gasto"
    static let description = IntentDescription("Regista um gasto nas Finanças do Mynik, na conta principal.")
    static let openAppWhenRun = false

    @Parameter(title: "Valor", description: "Quanto gastaste, em euros.", inclusiveRange: (0.01, 1_000_000))
    var amount: Double

    @Parameter(title: "Categoria")
    var category: CategoryEntity?

    @Parameter(title: "Descrição", description: "Opcional. Por omissão, o nome da categoria.")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Gastei \(\.$amount) em \(\.$category)") {
            \.$note
        }
    }

    init() {}

    init(amount: Double, category: CategoryEntity?, note: String? = nil) {
        self.amount = amount
        self.category = category
        self.note = note
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.shared.mainContext
        let model = category.flatMap { entity in
            QuickEntryService.expenseCategories(in: context).first { $0.uid == entity.id }
        }
        let value = Decimal(string: String(format: "%.2f", amount)) ?? Decimal(amount)
        let transaction = try QuickEntryService.addExpense(amount: value, category: model, title: note, in: context)
        IntentSideEffects.dataChanged(in: context)

        let place = model.map { " em \($0.name)" } ?? ""
        return .result(dialog: "Registei \(Currency.format(transaction.amount))\(place).")
    }
}

/// Saldo do mês por voz.
struct MonthBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Saldo do mês"
    static let description = IntentDescription("Diz quanto entrou, quanto saiu e o saldo do mês no Mynik.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let context = SharedModelContainer.shared.mainContext
        let snapshot = try WidgetSnapshotWriter.makeSnapshot(in: context, converter: IntentSideEffects.converter)
        let text = "Saldo de \(snapshot.monthName): \(Currency.format(snapshot.balance)). Entraram \(Currency.format(snapshot.income)) e saíram \(Currency.format(snapshot.expenses))."
        return .result(value: NSDecimalNumber(decimal: snapshot.balance).doubleValue, dialog: "\(text)")
    }
}

/// O que a app faria se estivesse aberta: widgets em dia.
@MainActor
enum IntentSideEffects {
    static var converter: CurrencyConverter {
        let stored = AppEnvironment.defaults.double(forKey: SettingsKey.brlPerEUR)
        return CurrencyConverter(storedRate: stored > 0 ? stored : CurrencyConverter.defaultBRLPerEUR)
    }

    static func dataChanged(in context: ModelContext) {
        WidgetSnapshotWriter.update(in: context, converter: converter)
    }
}
