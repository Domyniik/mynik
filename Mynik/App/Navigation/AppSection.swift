import Foundation

/// Secções de topo da app. Novos módulos entram aqui.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case assistant
    case finance
    case store
    case projects
    case goals
    case habits
    case investments
    case car
    case documents
    case career
    case notes
    case settings

    var id: Self { self }

    /// Secções com separador próprio no iPhone; as outras ficam em "Mais".
    static let primaryTabs: [AppSection] = [.today, .finance, .store, .projects]

    static var moreTabs: [AppSection] {
        allCases.filter { !primaryTabs.contains($0) }
    }

    var title: String {
        switch self {
        case .today: "Hoje"
        case .assistant: "Pergunte ao Mynik"
        case .finance: "Finanças"
        case .store: "Loja"
        case .projects: "Projetos"
        case .goals: "Metas"
        case .habits: "Hábitos"
        case .investments: "Património"
        case .car: "Carro"
        case .documents: "Documentos"
        case .career: "Carreira"
        case .notes: "Notas"
        case .settings: "Definições"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "sun.max"
        case .assistant: "sparkles"
        case .finance: "eurosign.circle"
        case .store: "storefront"
        case .projects: "checklist"
        case .goals: "target"
        case .habits: "flame"
        case .investments: "chart.line.uptrend.xyaxis"
        case .car: "car"
        case .documents: "person.text.rectangle"
        case .career: "briefcase"
        case .notes: "note.text"
        case .settings: "gearshape"
        }
    }
}
