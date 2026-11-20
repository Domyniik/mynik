import AppIntents
import SwiftData

/// Para a automação "Transação" dos Atalhos: cada pagamento com o Apple Pay
/// vira um gasto no Mynik, sem abrir a app.
///
/// A categoria é a do último gasto no mesmo comerciante (ou adivinhada pelo
/// nome); um pagamento repetido no mesmo minuto não é registado duas vezes.
struct ApplePayTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Registar compra do Apple Pay"
    static let description = IntentDescription(
        "Regista um pagamento com o Apple Pay como gasto. Usa na automação \"Transação\" dos Atalhos: Comerciante → Comerciante, Montante → Valor."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Comerciante")
    var merchant: String

    @Parameter(title: "Valor", description: "O montante da transação, por exemplo \"12,50 €\".")
    var amount: String

    @Parameter(title: "Cartão")
    var card: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Registar \(\.$amount) em \(\.$merchant)") {
            \.$card
        }
    }

    init() {}

    init(merchant: String, amount: String, card: String? = nil) {
        self.merchant = merchant
        self.amount = amount
        self.card = card
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.shared.mainContext
        let result = try ApplePayEntry.register(merchant: merchant, amountText: amount, card: card, in: context)
        IntentSideEffects.dataChanged(in: context)
        return .result(dialog: "\(result.message)")
    }
}

/// Lógica da automação do Apple Pay (separada do intent para os testes).
@MainActor
enum ApplePayEntry {
    struct Outcome {
        let transaction: FinanceTransaction
        let isDuplicate: Bool

        var message: String {
            let value = Currency.format(transaction.amount, code: transaction.currencyCode)
            if isDuplicate { return "Esta compra (\(value) em \(transaction.title)) já estava registada." }
            let category = transaction.category.map { " · \($0.name)" } ?? ""
            return "Registei \(value) em \(transaction.title)\(category)."
        }
    }

    static func register(
        merchant: String,
        amountText: String,
        card: String?,
        date: Date = .now,
        in context: ModelContext
    ) throws -> Outcome {
        guard let parsed = AmountTextParser.parse(amountText) else {
            throw QuickEntryError.unreadableAmount(amountText)
        }
        let title = merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Apple Pay" : merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let minute = Int(date.timeIntervalSince1970 / 60)
        let externalID = "applepay:\(title.searchKey)|\(parsed.amount)|\(minute)"
        if let existing = LinkedTransactionService.existing(externalID, in: context) {
            return Outcome(transaction: existing, isDuplicate: true)
        }

        let category = QuickEntryService.lastCategory(forTitle: title, in: context)
            ?? CategorizationService.suggestWithRules(title: title, kind: .expense, in: context)
            ?? QuickEntryService.category(matching: title, in: context)
            ?? QuickEntryService.category(matching: "Outros", in: context)
        let cardName = card?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let transaction = try QuickEntryService.addExpense(
            amount: parsed.amount,
            category: category,
            title: title,
            currencyCode: parsed.currencyCode,
            date: date,
            externalID: externalID,
            notes: cardName.isEmpty ? "Apple Pay" : "Apple Pay · \(cardName)",
            in: context
        )
        return Outcome(transaction: transaction, isDuplicate: false)
    }
}
