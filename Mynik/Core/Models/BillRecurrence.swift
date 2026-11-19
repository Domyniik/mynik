import Foundation

nonisolated enum BillRecurrence: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case weekly
    case monthly
    case yearly

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "Única"
        case .weekly: "Semanal"
        case .monthly: "Mensal"
        case .yearly: "Anual"
        }
    }
}
