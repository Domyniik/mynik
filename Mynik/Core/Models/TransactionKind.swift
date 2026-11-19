import Foundation

/// Tipo de movimento financeiro.
nonisolated enum TransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income

    var id: Self { self }

    var title: String {
        switch self {
        case .expense: "Gasto"
        case .income: "Receita"
        }
    }

    var symbolName: String {
        switch self {
        case .expense: "arrow.up.right"
        case .income: "arrow.down.left"
        }
    }
}
