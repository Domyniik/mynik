import Foundation
import SwiftData

/// De onde vem o valor já juntado de uma meta.
nonisolated enum GoalSource: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Valor escrito à mão (com contribuições registadas na meta).
    case manual
    /// Saldo de uma conta (ex.: conta poupança).
    case account
    /// Soma dos movimentos de uma categoria desde o início da meta.
    case category

    var id: Self { self }

    var title: String {
        switch self {
        case .manual: "Valor manual"
        case .account: "Saldo de uma conta"
        case .category: "Movimentos de uma categoria"
        }
    }

    var explanation: String {
        switch self {
        case .manual: "Registas tu cada valor que juntas."
        case .account: "O progresso é o saldo atual da conta escolhida."
        case .category: "Soma os movimentos da categoria desde o início da meta. Cada contribuição cria um movimento nas Finanças."
        }
    }
}

/// Meta de poupança com valor-alvo (viagem, carro, fundo de emergência...).
@Model
final class Goal {
    var title: String = ""
    var targetAmount: Decimal = 0
    var currencyCode: String = Currency.defaultCode
    var deadline: Date?
    /// Nome de um SF Symbol.
    var symbolName: String = "target"
    /// Nome de uma cor de `CategoryColor`.
    var colorName: String = CategoryColor.green.rawValue
    var sourceRaw: String = GoalSource.manual.rawValue
    /// Valor juntado quando a origem é manual.
    var manualAmount: Decimal = 0
    /// Os movimentos da categoria contam a partir deste dia.
    var startDate: Date = Date.now
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    var account: Account?
    var category: Category?

    var source: GoalSource {
        get { GoalSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var color: CategoryColor {
        CategoryColor(rawValue: colorName) ?? .green
    }

    init(
        title: String,
        targetAmount: Decimal,
        currencyCode: String = Currency.defaultCode,
        deadline: Date? = nil,
        source: GoalSource = .manual,
        symbolName: String = "target",
        color: CategoryColor = .green,
        startDate: Date = .now,
        account: Account? = nil,
        category: Category? = nil
    ) {
        self.title = title
        self.targetAmount = targetAmount
        self.currencyCode = currencyCode
        self.deadline = deadline
        self.sourceRaw = source.rawValue
        self.symbolName = symbolName
        self.colorName = color.rawValue
        self.startDate = startDate
        self.account = account
        self.category = category
    }
}
