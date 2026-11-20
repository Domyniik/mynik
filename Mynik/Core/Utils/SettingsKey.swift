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
}
