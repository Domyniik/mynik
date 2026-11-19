import Foundation

/// Secções de topo da app. Novos módulos (Loja, Projetos, Notas...) entram aqui.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case finance

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Hoje"
        case .finance: "Finanças"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "sun.max"
        case .finance: "eurosign.circle"
        }
    }
}
