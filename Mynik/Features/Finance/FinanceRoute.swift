import Foundation

/// Ecrãs secundários de Finanças, abertos a partir da lista principal.
enum FinanceRoute: String, CaseIterable, Identifiable, Hashable {
    case bills
    case budget

    var id: Self { self }

    var title: String {
        switch self {
        case .bills: "Contas a pagar"
        case .budget: "Orçamento"
        }
    }

    var symbolName: String {
        switch self {
        case .bills: "calendar.badge.clock"
        case .budget: "chart.bar.doc.horizontal"
        }
    }
}
