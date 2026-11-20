import Foundation

/// Custos que a Shopify não conhece e que entram no lucro real.
///
/// Guardados nas Definições (`UserDefaults`); os valores por omissão são
/// estimativas razoáveis para uma loja pequena em Portugal.
nonisolated struct StoreCostSettings: Equatable, Sendable {
    /// Taxa percentual do processador de pagamentos (ex.: 2,1 %).
    var paymentFeePercent: Double = Self.defaultFeePercent
    /// Parte fixa da taxa por pedido (ex.: 0,25 €).
    var paymentFeeFixed: Double = Self.defaultFeeFixed
    /// Quanto custa enviar um pedido (portes + embalagem).
    var shippingCostPerOrder: Double = Self.defaultShippingCost
    /// Anúncios gerais por mês, não atribuídos a um produto.
    var monthlyAdSpend: Double = 0

    static let defaultFeePercent = 2.1
    static let defaultFeeFixed = 0.25
    static let defaultShippingCost = 4.0

    init(
        paymentFeePercent: Double = Self.defaultFeePercent,
        paymentFeeFixed: Double = Self.defaultFeeFixed,
        shippingCostPerOrder: Double = Self.defaultShippingCost,
        monthlyAdSpend: Double = 0
    ) {
        self.paymentFeePercent = paymentFeePercent
        self.paymentFeeFixed = paymentFeeFixed
        self.shippingCostPerOrder = shippingCostPerOrder
        self.monthlyAdSpend = monthlyAdSpend
    }

    init(defaults: UserDefaults) {
        func value(_ key: String, _ fallback: Double) -> Double {
            defaults.object(forKey: key) as? Double ?? fallback
        }
        self.init(
            paymentFeePercent: value(SettingsKey.storeFeePercent, Self.defaultFeePercent),
            paymentFeeFixed: value(SettingsKey.storeFeeFixed, Self.defaultFeeFixed),
            shippingCostPerOrder: value(SettingsKey.storeShippingCost, Self.defaultShippingCost),
            monthlyAdSpend: value(SettingsKey.storeMonthlyAds, 0)
        )
    }

    /// Taxa de pagamento de um pedido com este total.
    func paymentFee(for total: Decimal) -> Decimal {
        guard total > 0 else { return 0 }
        return total * Decimal.from(paymentFeePercent) / 100 + Decimal.from(paymentFeeFixed)
    }

    var shippingCost: Decimal { Decimal.from(shippingCostPerOrder) }
    var monthlyAds: Decimal { Decimal.from(monthlyAdSpend) }
}

extension Decimal {
    /// Converte um `Double` vindo das Definições sem lixo binário (2.1 → 2.1).
    nonisolated static func from(_ value: Double) -> Decimal {
        Decimal(string: String(value)) ?? Decimal(value)
    }

    nonisolated var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
