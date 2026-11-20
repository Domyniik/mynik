import Foundation

/// Chaves das preferências guardadas em `UserDefaults` / `@AppStorage`.
nonisolated enum SettingsKey {
    static let billRemindersEnabled = "billRemindersEnabled"
    static let billReminderDaysBefore = "billReminderDaysBefore"
    static let brlPerEUR = "brlPerEUR"
    static let exchangeRateDate = "exchangeRateDate"
    static let shopifyDomain = "shopifyDomain"
    static let shopifyShopName = "shopifyShopName"
    static let storeLastSync = "storeLastSync"
    /// Origem dos dados em cache da loja: "demo" ou "shopify:<domínio>".
    static let storeCacheSource = "storeCacheSource"
    static let storeFeePercent = "storeFeePercent"
    static let storeFeeFixed = "storeFeeFixed"
    static let storeShippingCost = "storeShippingCost"
    static let storeMonthlyAds = "storeMonthlyAds"
    static let storeSaleNotifications = "storeSaleNotifications"
    static let storeNoSaleDays = "storeNoSaleDays"
    /// Dia (yyyy-MM-dd) do último aviso de "dias sem venda".
    static let storeLastNoSaleAlert = "storeLastNoSaleAlert"
    /// IDs dos últimos pedidos já notificados.
    static let storeNotifiedOrders = "storeNotifiedOrders"
}
