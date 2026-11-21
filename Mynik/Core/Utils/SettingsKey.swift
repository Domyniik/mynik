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
    static let storeProfitToFinance = "storeProfitToFinance"
    /// URL (ou ID) da folha do Google Sheets com o gasto do Google Ads.
    static let googleAdsSheet = "googleAdsSheet"
    /// Gasto do Google Ads sem produto, últimos 30 dias (EUR).
    static let googleAdsUnattributed30d = "googleAdsUnattributed30d"
    /// Gasto total do Google Ads, últimos 30 dias (EUR).
    static let googleAdsTotal30d = "googleAdsTotal30d"
    static let googleAdsLastImport = "googleAdsLastImport"
    /// Vista das tarefas: "board" (Kanban) ou "list".
    static let taskLayout = "taskLayout"
    /// Lembretes dos prazos da agenda (carro, documentos, follow-ups).
    static let agendaRemindersEnabled = "agendaRemindersEnabled"
    /// Província dos preços de combustível (código de 2 dígitos).
    static let fuelProvinceID = "fuelProvinceID"
    /// Ordenar os postos pela distância (pede a localização).
    static let fuelUsesLocation = "fuelUsesLocation"
    /// Veículo escolhido no ecrã Carro.
    static let selectedVehicleUID = "selectedVehicleUID"
    /// Meta de poupança mensal (EUR); `0` = sem meta.
    static let savingsMonthlyTarget = "savingsMonthlyTarget"
    /// Os `uid` dos registos anteriores à v0.6 já foram tornados únicos.
    static let stableIDsRepaired = "stableIDsRepaired"
    /// Mac: ícone do Mynik na barra de menus.
    static let showMenuBarExtra = "showMenuBarExtra"
    /// Eventos do Calendário e lembretes na tela Hoje.
    static let showCalendarOnToday = "showCalendarOnToday"
    /// Sugerir a categoria dos movimentos novos (IA no dispositivo ou regras).
    static let autoCategorize = "autoCategorize"
    /// iPhone: Live Activity / Dynamic Island da conta que vence hoje.
    static let billLiveActivity = "billLiveActivity"
    /// Notificação da revisão semanal (domingo às 19h).
    static let weeklyReviewReminder = "weeklyReviewReminder"
    /// Pedir Face ID / Touch ID para abrir a app.
    static let appLockEnabled = "appLockEnabled"
}
