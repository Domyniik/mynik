import SwiftUI

/// Ecrã raiz de cada secção.
struct SectionDestination: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .today: TodayView()
        case .assistant: AskMynikView()
        case .finance: FinanceView()
        case .store: StoreView()
        case .projects: ProjectsView()
        case .goals: GoalsView()
        case .investments: InvestmentsView()
        case .car: CarView()
        case .documents: DocumentsView()
        case .career: CareerView()
        case .notes: NotesView()
        case .settings: SettingsView()
        }
    }
}
