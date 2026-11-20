import Foundation
import SwiftData

/// Resumo de um dia da loja: vendas (dos pedidos) e tráfego (do ShopifyQL).
///
/// É reconstruído a cada sincronização para os dias da janela sincronizada.
@Model
final class DailyStat {
    /// Início do dia (fuso horário local).
    var date: Date = Date.now
    /// Total pago pelos clientes nesse dia (sem cancelados).
    var sales: Decimal = 0
    /// Receita sem IVA, já sem devoluções.
    var netRevenue: Decimal = 0
    var orders: Int = 0
    var units: Int = 0
    var refunds: Decimal = 0
    /// Visitas à loja online.
    var sessions: Int = 0
    /// Visitas com pelo menos um artigo adicionado ao carrinho.
    var cartSessions: Int = 0
    /// Visitas que chegaram ao checkout.
    var checkoutSessions: Int = 0
    /// Visitas que terminaram em compra.
    var completedSessions: Int = 0
    /// `false` quando não há dados de tráfego (ex.: sem o scope `read_reports`).
    var hasTraffic: Bool = false

    init(date: Date) {
        self.date = date
    }
}
