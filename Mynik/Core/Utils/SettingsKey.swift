import Foundation

/// Chaves das preferências guardadas em `UserDefaults` / `@AppStorage`.
nonisolated enum SettingsKey {
    static let billRemindersEnabled = "billRemindersEnabled"
    static let billReminderDaysBefore = "billReminderDaysBefore"
    static let brlPerEUR = "brlPerEUR"
    static let exchangeRateDate = "exchangeRateDate"
    static let shopifyDomain = "shopifyDomain"
    static let shopifyShopName = "shopifyShopName"
}
