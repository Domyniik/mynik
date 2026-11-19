import SwiftUI

/// Ecrã raiz de cada secção.
struct SectionDestination: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .today: TodayView()
        case .finance: FinanceView()
        }
    }
}
