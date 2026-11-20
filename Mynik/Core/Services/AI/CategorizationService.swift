import Foundation
import FoundationModels
import SwiftData

/// Sugere a categoria de um movimento a partir da descrição.
///
/// 1. Histórico do utilizador (se já categorizou o mesmo comerciante, usa essa).
/// 2. Apple Intelligence (Foundation Models), quando disponível, com a resposta
///    limitada às categorias existentes.
/// 3. Regras por comerciante e palavras conhecidas, quando o modelo não existe ou falha.
@MainActor
enum CategorizationService {
    /// Sugestão já resolvida para uma categoria da base de dados.
    struct Result {
        let category: Category
        let source: CategorySuggestionSource
    }

    /// Ligado por omissão; pode desligar-se nas Definições.
    static var isEnabled: Bool {
        AppEnvironment.defaults.object(forKey: SettingsKey.autoCategorize) as? Bool ?? true
    }

    static func suggest(
        title: String,
        kind: TransactionKind,
        in context: ModelContext,
        useModel: Bool = AppleIntelligence.status.isAvailable
    ) async -> Result? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return nil }
        let categories = categories(of: kind, in: context)
        guard !categories.isEmpty else { return nil }
        let names = categories.map(\.name)
        let rules = MerchantCategoryRules(history: history(of: kind, in: context))

        func resolve(_ suggestion: MerchantCategoryRules.Suggestion?) -> Result? {
            guard let suggestion,
                  let category = categories.first(where: { $0.name == suggestion.categoryName })
            else { return nil }
            return Result(category: category, source: suggestion.source)
        }

        if let fromHistory = resolve(rules.historySuggestion(for: trimmed, among: names)) {
            return fromHistory
        }
        if useModel, let name = await ModelCategorizer.category(for: trimmed, kind: kind, among: names),
           let category = categories.first(where: { $0.name == name }) {
            return Result(category: category, source: .appleIntelligence)
        }
        return resolve(rules.keywordSuggestion(for: trimmed, among: names))
    }

    /// Versão síncrona, só com regras (Siri e Apple Pay, onde não há espera).
    static func suggestWithRules(title: String, kind: TransactionKind, in context: ModelContext) -> Category? {
        RuleCategorizer(in: context).category(for: title, kind: kind)
    }

    fileprivate static func categories(of kind: TransactionKind, in context: ModelContext) -> [Category] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.kindRaw == raw },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Os últimos 500 movimentos categorizados do mesmo tipo.
    fileprivate static func history(of kind: TransactionKind, in context: ModelContext) -> [MerchantCategoryRules.HistoryEntry] {
        let raw = kind.rawValue
        var descriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.kindRaw == raw && $0.category != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        let transactions = (try? context.fetch(descriptor)) ?? []
        return transactions.compactMap { transaction in
            transaction.category.map {
                MerchantCategoryRules.HistoryEntry(title: transaction.title, categoryName: $0.name, date: transaction.date)
            }
        }
    }
}

/// Regras carregadas uma só vez, para categorizar muitos movimentos (importação CSV).
@MainActor
struct RuleCategorizer {
    private let categories: [TransactionKind: [Category]]
    private let rules: [TransactionKind: MerchantCategoryRules]

    init(in context: ModelContext) {
        var categories: [TransactionKind: [Category]] = [:]
        var rules: [TransactionKind: MerchantCategoryRules] = [:]
        for kind in TransactionKind.allCases {
            categories[kind] = CategorizationService.categories(of: kind, in: context)
            rules[kind] = MerchantCategoryRules(history: CategorizationService.history(of: kind, in: context))
        }
        self.categories = categories
        self.rules = rules
    }

    func category(for title: String, kind: TransactionKind) -> Category? {
        let options = categories[kind] ?? []
        guard let name = rules[kind]?.suggest(for: title, among: options.map(\.name))?.categoryName else { return nil }
        return options.first { $0.name == name }
    }
}

/// Pergunta ao modelo do dispositivo qual a categoria, só entre as existentes.
nonisolated enum ModelCategorizer {
    static func category(for title: String, kind: TransactionKind, among names: [String]) async -> String? {
        guard !names.isEmpty else { return nil }
        let instructions = """
            Classificas movimentos bancários de uma pessoa que vive em Espanha. \
            Responde só com uma das categorias dadas. Se nenhuma servir, escolhe a mais genérica.
            """
        let session = LanguageModelSession(instructions: instructions)
        let schema: GenerationSchema
        do {
            schema = try GenerationSchema(
                root: DynamicGenerationSchema(name: "Categoria", description: "Categoria do movimento", anyOf: names),
                dependencies: []
            )
        } catch {
            return nil
        }
        let kindText = kind == .expense ? "gasto" : "receita"
        do {
            let response = try await session.respond(
                to: "Descrição do \(kindText): \"\(title)\". Categorias possíveis: \(names.joined(separator: ", ")).",
                schema: schema,
                options: GenerationOptions(sampling: .greedy)
            )
            let value = try response.content.value(String.self)
            return names.first { $0 == value }
        } catch {
            return nil
        }
    }
}
