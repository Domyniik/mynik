import SwiftUI

/// Ecrã raiz de cada secção.
struct SectionDestination: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .today: TodayView()
        case .finance: FinanceView()
        case .store: StoreView()
        case .projects: ProjectsView()
        case .goals: GoalsView()
        case .car: CarView()
        case .notes: NotesView()
        case .settings: SettingsView()
        }
    }
}
