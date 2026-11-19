import Foundation

nonisolated enum AccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case checking
    case savings
    case card
    case cash

    var id: Self { self }

    var title: String {
        switch self {
        case .checking: "Conta à ordem"
        case .savings: "Poupança"
        case .card: "Cartão"
        case .cash: "Dinheiro"
        }
    }

    var symbolName: String {
        switch self {
        case .checking: "building.columns"
        case .savings: "banknote"
        case .card: "creditcard"
        case .cash: "eurosign"
        }
    }
}
