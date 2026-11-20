import Foundation

/// Secções de topo da app. Novos módulos (Loja, Projetos, Notas...) entram aqui.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case finance
    case store
    case projects
    case goals
    case notes
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Hoje"
        case .finance: "Finanças"
        case .store: "Loja"
        case .projects: "Projetos"
        case .goals: "Metas"
        case .notes: "Notas"
        case .settings: "Definições"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "sun.max"
        case .finance: "eurosign.circle"
        case .store: "storefront"
        case .projects: "checklist"
        case .goals: "target"
        case .notes: "note.text"
        case .settings: "gearshape"
        }
    }
}
