import Foundation
import UserNotifications

/// Notificações locais da loja: novas vendas e dias sem vender.
///
/// Sem servidor nem push remoto: são criadas no próprio dispositivo depois
/// de cada sincronização (ao abrir a app ou em segundo plano).
@MainActor
enum StoreNotifier {
    static let saleIdentifierPrefix = "store-sale-"
    static let noSaleIdentifierPrefix = "store-no-sale-"
    /// Quantos IDs de pedidos já notificados guardar (para nunca repetir).
    static let rememberedOrders = 200

    struct Sale: Equatable {
        var orderID: String
        var name: String
        var total: Decimal
        var itemTitles: [String]
    }

    static var saleNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.storeSaleNotifications) as? Bool ?? true
    }

    static var noSaleDays: Int {
        UserDefaults.standard.object(forKey: SettingsKey.storeNoSaleDays) as? Int ?? StoreAlerts.defaultNoSaleDays
    }

    /// Texto da notificação de uma venda.
    static func content(for sale: Sale) -> (title: String, body: String) {
        let items = sale.itemTitles.prefix(2).joined(separator: ", ") + (sale.itemTitles.count > 2 ? "…" : "")
        return ("Nova venda \(sale.name) · \(Currency.format(sale.total))", items.isEmpty ? "Pedido na Neloce" : items)
    }

    /// Notifica as vendas ainda não notificadas (no máximo 3 de cada vez).
    static func notifySales(_ sales: [Sale], defaults: UserDefaults = .standard) async {
        guard saleNotificationsEnabled, !sales.isEmpty else { return }
        var notified = defaults.stringArray(forKey: SettingsKey.storeNotifiedOrders) ?? []
        let fresh = sales.filter { !notified.contains($0.orderID) }
        guard !fresh.isEmpty, await NotificationService.shared.requestAuthorizationIfNeeded() else { return }

        if fresh.count > 3 {
            let total = fresh.reduce(Decimal(0)) { $0 + $1.total }
            await deliver(id: saleIdentifierPrefix + "batch-\(Date.now.timeIntervalSince1970)",
                          title: "\(fresh.count) novas vendas · \(Currency.format(total))",
                          body: fresh.map(\.name).joined(separator: ", "))
        } else {
            for sale in fresh {
                let text = content(for: sale)
                await deliver(id: saleIdentifierPrefix + sale.orderID, title: text.title, body: text.body)
            }
        }

        notified += fresh.map(\.orderID)
        defaults.set(Array(notified.suffix(rememberedOrders)), forKey: SettingsKey.storeNotifiedOrders)
    }

    /// Avisa uma vez por dia quando a loja está há `noSaleDays` dias sem vender.
    static func notifyNoSalesIfNeeded(daysWithoutSales: Int?, now: Date = .now, defaults: UserDefaults = .standard) async {
        guard let days = daysWithoutSales, days >= noSaleDays else { return }
        let today = now.formatted(.iso8601.year().month().day())
        guard defaults.string(forKey: SettingsKey.storeLastNoSaleAlert) != today,
              await NotificationService.shared.requestAuthorizationIfNeeded()
        else { return }

        await deliver(
            id: noSaleIdentifierPrefix + today,
            title: "\(days) dias sem venda na loja",
            body: "Abre o Mynik para ver o funil e o ranking dos produtos."
        )
        defaults.set(today, forKey: SettingsKey.storeLastNoSaleAlert)
    }

    private static func deliver(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "store"
        // Sem gatilho: aparece já.
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
