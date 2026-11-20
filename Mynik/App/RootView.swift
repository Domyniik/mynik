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
            .task { await refreshStorePeriodically() }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active {
                    rescheduleReminders()
                    recordWealthSnapshot()
                    refreshExchangeRateIfStale()
                    Task { await storeSync.refreshIfStale(in: modelContext) }
                } else if scenePhase == .background {
                    StoreBackgroundRefresh.schedule()
                    // Os documentos voltam a ficar escondidos.
                    BiometricLock.shared.lock()
                }
            }
    }

    /// No Mac não há atualização em segundo plano: enquanto a app está aberta,
    /// a loja atualiza de 15 em 15 minutos (para as notificações de venda).
    private func refreshStorePeriodically() async {
        #if os(macOS)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(StoreSyncCoordinator.minimumInterval))
            guard !Task.isCancelled else { return }
            await storeSync.refreshIfStale(in: modelContext)
        }
        #endif
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

    /// Uma fotografia do património por dia, para o gráfico da evolução.
    private func recordWealthSnapshot() {
        InvestmentService.recordSnapshot(
            in: modelContext,
            converter: CurrencyConverter(storedRate: brlPerEUR)
        )
        try? modelContext.save()
    }

    private func rescheduleReminders() {
        Task {
            await NotificationService.shared.rescheduleReminders(in: modelContext)
        }
    }
}

#Preview(traits: .sampleData) {
    RootView()
}
