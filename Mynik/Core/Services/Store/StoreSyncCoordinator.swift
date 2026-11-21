import Foundation
import Observation
import SwiftData

/// Sincroniza a cache da loja e guarda o estado para a interface.
///
/// Sem credenciais da Shopify usa a loja de exemplo, para que o módulo
/// funcione (e se possa demonstrar) antes de ligar a loja real.
@MainActor
@Observable
final class StoreSyncCoordinator {
    /// Dias de pedidos pedidos à Shopify (30 dias + os 30 anteriores, para comparar).
    static let syncWindowDays = 60
    /// Intervalo mínimo entre atualizações automáticas.
    static let minimumInterval: TimeInterval = 15 * 60

    private(set) var isSyncing = false
    private(set) var lastError: String?
    private(set) var trafficWarning: String?
    /// Erro da última leitura do Google Ads (não impede a sincronização da loja).
    private(set) var adsWarning: String?
    private(set) var lastSyncedAt: Date?
    private(set) var shopName: String
    /// `true` enquanto a cache tem os dados de exemplo.
    private(set) var isDemo: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        let lastSync = defaults.double(forKey: SettingsKey.storeLastSync)
        lastSyncedAt = lastSync > 0 ? Date(timeIntervalSince1970: lastSync) : nil
        shopName = defaults.string(forKey: SettingsKey.shopifyShopName) ?? ""
        isDemo = (defaults.string(forKey: SettingsKey.storeCacheSource) ?? Self.demoSource) == Self.demoSource
    }

    private static let demoSource = "demo"

    /// Fonte que a cache deve ter: a loja ligada ou os dados de exemplo.
    private var desiredSource: String {
        guard let domain = defaults.string(forKey: SettingsKey.shopifyDomain), !domain.isEmpty else {
            return Self.demoSource
        }
        return "shopify:\(domain)"
    }

    /// Atualiza se passou o intervalo mínimo ou se a loja ligada mudou.
    func refreshIfStale(in context: ModelContext, now: Date = .now) async {
        let sourceChanged = defaults.string(forKey: SettingsKey.storeCacheSource) != desiredSource
        let isStale = lastSyncedAt.map { now.timeIntervalSince($0) >= Self.minimumInterval } ?? true
        let isEmpty = ((try? context.fetchCount(FetchDescriptor<DailyStat>())) ?? 0) == 0
        guard sourceChanged || isStale || isEmpty else { return }
        await refresh(in: context, now: now)
    }

    @discardableResult
    func refresh(in context: ModelContext, now: Date = .now) async -> StoreCacheWriter.Result? {
        guard !isSyncing else { return nil }
        isSyncing = true
        defer { isSyncing = false }

        let source = desiredSource
        let credentials = source == Self.demoSource ? nil : ShopifyCredentials.load()
        let dataSource: any StoreDataSource = if let credentials {
            ShopifyStoreDataSource(client: ShopifyClient(credentials: credentials), calendar: calendar)
        } else {
            DemoStoreDataSource(now: now, calendar: calendar)
        }
        let today = calendar.startOfDay(for: now)
        let since = calendar.date(byAdding: .day, value: -(Self.syncWindowDays - 1), to: today) ?? today

        do {
            let snapshot = try await dataSource.fetchSnapshot(since: since)
            let cacheSource = credentials == nil ? Self.demoSource : source
            if defaults.string(forKey: SettingsKey.storeCacheSource) != cacheSource {
                try StoreCacheWriter.removeAll(from: context)
            }
            let result = try StoreCacheWriter.apply(snapshot, since: since, to: context, now: now, calendar: calendar)

            defaults.set(cacheSource, forKey: SettingsKey.storeCacheSource)
            defaults.set(now.timeIntervalSince1970, forKey: SettingsKey.storeLastSync)
            lastSyncedAt = now
            isDemo = credentials == nil
            shopName = snapshot.shopName
            trafficWarning = snapshot.trafficUnavailableReason
            lastError = nil

            // Notificações, Google Ads e lucro nas Finanças só para a loja real.
            if credentials != nil {
                await importGoogleAdsSpend(in: context, now: now)
                if StoreProfitPoster.isEnabled {
                    try StoreProfitPoster.post(in: context, costs: StoreCostSettings(defaults: defaults), since: since, now: now, calendar: calendar)
                }
                await notify(result, in: context, now: now)
            }
            return result
        } catch is CancellationError {
            return nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    /// Lê o gasto do Google Ads da folha configurada nas Definições, se houver.
    func importGoogleAdsSpend(in context: ModelContext, now: Date = .now) async {
        let input = defaults.string(forKey: SettingsKey.googleAdsSheet) ?? ""
        guard !input.isEmpty else {
            adsWarning = nil
            return
        }
        guard let sheetID = GoogleAdsSpendImporter.sheetID(from: input) else {
            adsWarning = GoogleAdsSpendImporter.ImportError.invalidSheet.errorDescription
            return
        }
        do {
            let rows = try await GoogleAdsSpendImporter.fetch(sheetID: sheetID)
            let rate = defaults.object(forKey: SettingsKey.brlPerEUR) as? Double ?? CurrencyConverter.defaultBRLPerEUR
            let summary = GoogleAdsSpendImporter.summarize(
                rows, now: now, calendar: calendar, converter: CurrencyConverter(storedRate: rate)
            )
            try GoogleAdsSpendImporter.apply(summary, to: context, defaults: defaults, now: now)
            adsWarning = nil
        } catch is CancellationError {
            return
        } catch {
            adsWarning = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func notify(_ result: StoreCacheWriter.Result, in context: ModelContext, now: Date) async {
        await StoreNotifier.notifySales(result.newOrders.map {
            StoreNotifier.Sale(orderID: $0.id, name: $0.name, total: $0.total, itemTitles: $0.itemTitles)
        })
        let orders = (try? context.fetch(FetchDescriptor<StoreOrder>())) ?? []
        await StoreNotifier.notifyNoSalesIfNeeded(
            daysWithoutSales: StoreAlerts.daysWithoutSales(orders: orders, now: now, calendar: calendar),
            now: now
        )
    }
}
