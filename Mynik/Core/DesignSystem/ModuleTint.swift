import SwiftUI

extension AppSection {
    /// Cor de destaque de cada módulo (ícones, gráficos e cabeçalhos).
    ///
    /// Os botões e controlos continuam com a cor da marca, para o contraste ser sempre bom.
    var tint: Color {
        switch self {
        case .today: .orange
        case .assistant: .purple
        case .finance: .green
        case .store: .pink
        case .projects: .blue
        case .goals: .red
        case .habits: .orange
        case .investments: .teal
        case .car: .indigo
        case .documents: .cyan
        case .career: .brown
        case .notes: .yellow
        case .settings: .gray
        }
    }
}

extension EnvironmentValues {
    /// Cor do módulo atual, lida pelos componentes do sistema visual.
    @Entry var moduleTint: Color = .brand
}
