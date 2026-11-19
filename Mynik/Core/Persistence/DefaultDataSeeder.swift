import Foundation
import SwiftData

/// Cria as categorias e a conta iniciais na primeira abertura.
enum DefaultDataSeeder {
    private struct CategorySeed {
        let name: String
        let symbolName: String
        let color: CategoryColor
        let kind: TransactionKind
    }

    private static let categories: [CategorySeed] = [
        .init(name: "Alimentação", symbolName: "cart", color: .orange, kind: .expense),
        .init(name: "Casa", symbolName: "house", color: .brown, kind: .expense),
        .init(name: "Transporte", symbolName: "tram", color: .blue, kind: .expense),
        .init(name: "Carro", symbolName: "car", color: .indigo, kind: .expense),
        .init(name: "Saúde", symbolName: "cross.case", color: .red, kind: .expense),
        .init(name: "Lazer", symbolName: "gamecontroller", color: .purple, kind: .expense),
        .init(name: "Compras", symbolName: "bag", color: .pink, kind: .expense),
        .init(name: "Assinaturas", symbolName: "repeat", color: .teal, kind: .expense),
        .init(name: "Outros", symbolName: "ellipsis.circle", color: .gray, kind: .expense),
        .init(name: "Salário", symbolName: "briefcase", color: .green, kind: .income),
        .init(name: "Loja", symbolName: "storefront", color: .mint, kind: .income),
        .init(name: "Outras receitas", symbolName: "plus.circle", color: .gray, kind: .income),
    ]

    static func seedIfNeeded(in context: ModelContext) throws {
        if try context.fetchCount(FetchDescriptor<Category>()) == 0 {
            for (index, seed) in categories.enumerated() {
                context.insert(
                    Category(
                        name: seed.name,
                        symbolName: seed.symbolName,
                        color: seed.color,
                        kind: seed.kind,
                        sortOrder: index
                    )
                )
            }
        }

        if try context.fetchCount(FetchDescriptor<Account>()) == 0 {
            context.insert(Account(name: "Conta principal"))
        }

        try context.save()
    }
}
