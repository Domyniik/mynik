import AppIntents
import SwiftData

/// Categoria de gasto, para a Siri e os Atalhos.
struct CategoryEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Categoria"
    static let defaultQuery = CategoryQuery()

    let id: String
    let name: String
    let symbolName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbolName))
    }

    init(_ category: Category) {
        id = category.uid
        name = category.name
        symbolName = category.symbolName
    }
}

struct CategoryQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        let context = SharedModelContainer.shared.mainContext
        return QuickEntryService.expenseCategories(in: context)
            .filter { identifiers.contains($0.uid) }
            .map(CategoryEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        let context = SharedModelContainer.shared.mainContext
        if let match = QuickEntryService.category(matching: string, in: context) {
            return [CategoryEntity(match)]
        }
        return []
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        QuickEntryService.expenseCategories(in: SharedModelContainer.shared.mainContext).map(CategoryEntity.init)
    }
}
