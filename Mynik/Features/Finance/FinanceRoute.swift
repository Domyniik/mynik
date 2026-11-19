import Foundation

/// Ecrãs secundários de Finanças, abertos a partir da lista principal.
enum FinanceRoute: String, CaseIterable, Identifiable, Hashable {
    case bills
    case budget
    case reports
    case subscriptions
    case importCSV

    var id: Self { self }

    var title: String {
        switch self {
        case .bills: "Contas a pagar"
        case .budget: "Orçamento"
        case .reports: "Relatórios"
        case .subscriptions: "Assinaturas"
        case .importCSV: "Importar CSV do banco"
        }
    }

    var symbolName: String {
        switch self {
        case .bills: "calendar.badge.clock"
        case .budget: "chart.bar.doc.horizontal"
        case .reports: "chart.pie"
        case .subscriptions: "repeat.circle"
        case .importCSV: "square.and.arrow.down"
        }
    }
}
