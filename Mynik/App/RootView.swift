import Combine
import SwiftData
import SwiftUI

/// Escolhe a navegação certa para cada dispositivo:
/// barra lateral no Mac/iPad, separadores no iPhone.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        navigation
            // Lembretes de vencimento sempre alinhados com os dados.
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                rescheduleReminders()
            }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active {
                    rescheduleReminders()
                }
            }
    }

    @ViewBuilder
    private var navigation: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            TabNavigationView()
        } else {
            SidebarNavigationView()
        }
        #else
        SidebarNavigationView()
        #endif
    }

    private func rescheduleReminders() {
        Task {
            await NotificationService.shared.rescheduleBillReminders(in: modelContext)
        }
    }
}

#Preview(traits: .sampleData) {
    RootView()
}
