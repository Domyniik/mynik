import Foundation
import SwiftData

/// Lançamentos rápidos vindos da Siri, dos Atalhos e da automação do Apple Pay.
@MainActor
enum QuickEntryService {
    /// Regista um gasto e devolve-o já guardado.
    @discardableResult
    static func addExpense(
        amount: Decimal,
        category: Category?,
        title: String?,
        currencyCode: String = Currency.defaultCode,
        date: Date = .now,
        externalID: String = "",
        notes: String = "",
        in context: ModelContext
    ) throws -> FinanceTransaction {
        guard amount > 0 else { throw QuickEntryError.invalidAmount }
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let transaction = FinanceTransaction(
            title: trimmed.isEmpty ? (category?.name ?? "Gasto") : trimmed,
            amount: amount,
            kind: .expense,
            date: date,
            currencyCode: currencyCode,
            notes: notes,
            category: category,
            account: LinkedTransactionService.defaultAccount(in: context)
        )
        transaction.externalID = externalID
        context.insert(transaction)
        try context.save()
        return transaction
    }

    /// Categorias de gasto pela ordem das Finanças.
    static func expenseCategories(in context: ModelContext) -> [Category] {
        let expense = TransactionKind.expense.rawValue
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.kindRaw == expense },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Categoria de gasto cujo nome corresponde ao texto dito ou escrito
    /// ("alimentação", "Alimentacao", "comida" → sinónimo conhecido).
    static func category(matching text: String, in context: ModelContext) -> Category? {
        let query = text.searchKey
        guard !query.isEmpty else { return nil }
        let categories = expenseCategories(in: context)
        if let exact = categories.first(where: { $0.name.searchKey == query }) { return exact }
        if let partial = categories.first(where: { $0.name.searchKey.contains(query) || query.contains($0.name.searchKey) }) {
            return partial
        }
        guard let synonym = synonyms.first(where: { $0.words.contains(query) })?.category else { return nil }
        return categories.first { $0.name.searchKey == synonym.searchKey }
    }

    /// Categoria do último gasto com o mesmo nome (para o comerciante do Apple Pay).
    static func lastCategory(forTitle title: String, in context: ModelContext) -> Category? {
        let expense = TransactionKind.expense.rawValue
        var descriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.title == title && $0.kindRaw == expense && $0.category != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.category
    }

    /// Palavras do dia a dia para as categorias iniciais.
    private static let synonyms: [(category: String, words: Set<String>)] = [
        ("Alimentação", ["comida", "supermercado", "mercado", "mercearia", "restaurante", "almoco", "jantar", "cafe"]),
        ("Transporte", ["metro", "autocarro", "comboio", "uber", "taxi", "bolt"]),
        ("Carro", ["gasolina", "gasoleo", "combustivel", "estacionamento", "portagem"]),
        ("Saúde", ["farmacia", "medico", "dentista"]),
        ("Lazer", ["cinema", "bar", "copos", "viagem", "jogos"]),
        ("Compras", ["roupa", "loja", "amazon"]),
        ("Casa", ["renda", "luz", "agua", "gas", "internet"]),
    ]
}

nonisolated enum QuickEntryError: LocalizedError {
    case invalidAmount
    case unreadableAmount(String)

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "O valor tem de ser maior que zero."
        case .unreadableAmount(let text): "Não percebi o valor \"\(text)\"."
        }
    }
}

extension String {
    /// Texto para comparar nomes: sem maiúsculas, acentos nem espaços nas pontas.
    nonisolated var searchKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .app)
    }
}
