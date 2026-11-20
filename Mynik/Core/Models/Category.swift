import Foundation
import SwiftData

/// Categoria de gasto ou receita (ex.: Alimentação, Carro, Salário).
@Model
final class Category {
    /// Identificador estável entre dispositivos (cópias de segurança e importação).
    var uid: String = UUID().uuidString
    var name: String = ""
    /// Nome de um SF Symbol.
    var symbolName: String = "tag"
    /// Nome de uma cor de `CategoryColor`.
    var colorName: String = CategoryColor.gray.rawValue
    var kindRaw: String = TransactionKind.expense.rawValue
    var sortOrder: Int = 0
    /// Orçamento mensal em EUR. `0` significa sem orçamento.
    var monthlyBudget: Decimal = 0

    @Relationship(deleteRule: .nullify, inverse: \FinanceTransaction.category)
    var transactions: [FinanceTransaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Bill.category)
    var bills: [Bill]? = []

    /// Metas cujo progresso soma os movimentos desta categoria.
    @Relationship(deleteRule: .nullify, inverse: \Goal.category)
    var goals: [Goal]? = []

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var color: CategoryColor {
        CategoryColor(rawValue: colorName) ?? .gray
    }

    init(
        name: String,
        symbolName: String,
        color: CategoryColor,
        kind: TransactionKind,
        sortOrder: Int = 0
    ) {
        self.name = name
        self.symbolName = symbolName
        self.colorName = color.rawValue
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
    }
}
