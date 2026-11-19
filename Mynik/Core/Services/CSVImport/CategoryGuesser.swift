import Foundation

/// Sugere a categoria de um movimento importado a partir do histórico:
/// se já houve um movimento com a mesma descrição, usa a mesma categoria.
struct CategoryGuesser {
    private var categoriesByTitle: [String: Category] = [:]

    init(history: [FinanceTransaction]) {
        // Do mais antigo para o mais recente: a categoria mais recente ganha.
        for transaction in history.sorted(by: { $0.date < $1.date }) {
            guard let category = transaction.category else { continue }
            categoriesByTitle[BankCSVImporter.normalize(transaction.title)] = category
        }
    }

    func category(for row: BankCSVImporter.Row) -> Category? {
        guard let category = categoriesByTitle[BankCSVImporter.normalize(row.title)],
              category.kind == row.kind
        else { return nil }
        return category
    }
}
