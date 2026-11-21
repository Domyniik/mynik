import Combine
import SwiftData
import SwiftUI

/// Escolhe a navegação certa para cada dispositivo:
/// barra lateral no iPad, separadores no iPhone.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(StoreSyncCoordinator.self) private var storeSync
    @Environment(AppRouter.self) private var router
    @Environment(AccountSync.self) private var accountSync
    @State private var appLock = AppLock.shared

    @AppStorage(SettingsKey.brlPerEUR) private var brlPerEUR = CurrencyConverter.defaultBRLPerEUR
    @AppStorage(SettingsKey.exchangeRateDate) private var exchangeRateDate = ""

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        @Bindable var router = router
        navigation
            .environment(\.currencyConverter, CurrencyConverter(storedRate: brlPerEUR))
            // Reduzir movimento: sem animações de deslocação em toda a app.
            .transaction { transaction in
                if reduceMotion { transaction.animation = nil }
            }
            // Bloqueio com Face ID: tapa tudo enquanto bloqueada e no seletor de apps.
            .overlay {
                if appLock.isLocked {
                    AppLockView(lock: appLock, asksForUnlock: scenePhase == .active)
                } else if appLock.isEnabled, scenePhase != .active {
                    AppLockView(lock: appLock, asksForUnlock: false)
                }
            }
            .sheet(isPresented: $router.isSearching) {
                GlobalSearchView()
                    .environment(\.currencyConverter, CurrencyConverter(storedRate: brlPerEUR))
            }
            // Lembretes de vencimento sempre alinhados com os dados.
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                accountSync.scheduleSync(context: modelContext)
                rescheduleReminders()
                updateWidgets()
                updateLiveActivity()
            }
            // Link de entrada do email (mynik://login…).
            .onOpenURL { url in
                guard AccountSync.isLoginURL(url) else { return }
                Task {
                    try? await accountSync.signIn(withLink: url)
                    await accountSync.sync(context: modelContext)
                }
            }
            .onChange(of: scenePhase, initial: true) {
                if scenePhase == .active {
                    appLock.didBecomeActive()
                    rescheduleReminders()
                    updateWidgets()
                    updateLiveActivity()
                    recordWealthSnapshot()
                    refreshExchangeRateIfStale()
                    Task { await storeSync.refreshIfStale(in: modelContext) }
                    accountSync.start()
                    Task { await accountSync.sync(context: modelContext) }
                } else if scenePhase == .background {
                    StoreBackgroundRefresh.schedule()
                    // Os documentos voltam a ficar escondidos.
                    BiometricLock.shared.lock()
                    appLock.didEnterBackground()
                }
            }
    }

    @ViewBuilder
    private var navigation: some View {
        if horizontalSizeClass == .compact {
            TabNavigationView()
        } else {
            SidebarNavigationView()
        }
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
        // No modo de demonstração nada sai da app (widgets, avisos, Live Activity).
        guard !AppEnvironment.isDemo else { return }
        InvestmentService.recordSnapshot(
            in: modelContext,
            converter: CurrencyConverter(storedRate: brlPerEUR)
        )
        try? modelContext.save()
    }

    /// Resumo para os widgets (saldo do mês e contas a vencer).
    private func updateWidgets() {
        // No modo de demonstração nada sai da app (widgets, avisos, Live Activity).
        guard !AppEnvironment.isDemo else { return }
        WidgetSnapshotWriter.update(in: modelContext, converter: CurrencyConverter(storedRate: brlPerEUR))
    }

    /// Live Activity da conta que vence hoje (iPhone).
    private func updateLiveActivity() {
        // No modo de demonstração nada sai da app (widgets, avisos, Live Activity).
        guard !AppEnvironment.isDemo else { return }
        BillLiveActivityService.sync(in: modelContext, converter: CurrencyConverter(storedRate: brlPerEUR))
    }

    private func rescheduleReminders() {
        // No modo de demonstração nada sai da app (widgets, avisos, Live Activity).
        guard !AppEnvironment.isDemo else { return }
        Task {
            await NotificationService.shared.rescheduleReminders(in: modelContext)
        }
    }
}

#Preview(traits: .sampleData) {
    RootView()
        .environment(AppRouter())
        .environment(AccountSync(config: nil))
}
