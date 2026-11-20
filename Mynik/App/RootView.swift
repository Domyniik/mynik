import Combine
import SwiftData
import SwiftUI

/// Escolhe a navegação certa para cada dispositivo:
/// barra lateral no Mac/iPad, separadores no iPhone.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(StoreSyncCoordinator.self) private var storeSync

    @AppStorage(SettingsKey.brlPerEUR) private var brlPerEUR = CurrencyConverter.defaultBRLPerEUR
    @AppStorage(SettingsKey.exchangeRateDate) private var exchangeRateDate = ""

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        navigation
            .environment(\.currencyConverter, CurrencyConverter(storedRate: brlPerEUR))
            // Lembretes de vencimento sempre alinhados com os dados.
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                rescheduleReminders()
            }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active {
                    rescheduleReminders()
                    refreshExchangeRateIfStale()
                    Task { await storeSync.refreshIfStale(in: modelContext) }
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

    /// Atualiza a taxa EUR/BRL uma vez por dia, em silêncio.
    private func refreshExchangeRateIfStale() {
        let today = Date.now.formatted(.iso8601.year().month().day())
        guard exchangeRateDate < today else { return }
        Task {
            guard let rate = try? await ExchangeRateService.fetchLatest() else { return }
            brlPerEUR = rate.brlPerEUR
            exchangeRateDate = rate.date
        }
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
