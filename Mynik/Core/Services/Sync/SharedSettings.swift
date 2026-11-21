import Foundation

/// Uma definição partilhada entre dispositivos (tabela `user_settings`).
nonisolated struct SettingRecord: Codable, Equatable, Sendable {
    var key: String
    var value: RawJSON
}

/// Definições que valem para a conta e não só para este dispositivo: os custos
/// da loja, a taxa BRL/EUR ou a meta de poupança entram nos cálculos (lucro
/// real, orçamento, poupança), por isso o iPhone e o desktop têm de as ver iguais.
///
/// Ficam de fora as do próprio dispositivo: bloqueio da app, calendário, Live
/// Activity, localização, veículo escolhido e o estado interno do sync e da loja.
nonisolated enum SharedSettings {
    enum Kind: Sendable { case double, int, bool, string }

    static let keys: [String: Kind] = [
        SettingsKey.brlPerEUR: .double,
        SettingsKey.exchangeRateDate: .string,
        SettingsKey.storeFeePercent: .double,
        SettingsKey.storeFeeFixed: .double,
        SettingsKey.storeShippingCost: .double,
        SettingsKey.storeMonthlyAds: .double,
        SettingsKey.storeSaleNotifications: .bool,
        SettingsKey.storeNoSaleDays: .int,
        SettingsKey.storeProfitToFinance: .bool,
        SettingsKey.googleAdsSheet: .string,
        SettingsKey.googleAdsUnattributed30d: .double,
        SettingsKey.googleAdsTotal30d: .double,
        SettingsKey.googleAdsLastImport: .double,
        SettingsKey.taskLayout: .string,
        SettingsKey.fuelProvinceID: .string,
        SettingsKey.savingsMonthlyTarget: .double,
        SettingsKey.autoCategorize: .bool,
        SettingsKey.billRemindersEnabled: .bool,
        SettingsKey.billReminderDaysBefore: .int,
        SettingsKey.agendaRemindersEnabled: .bool,
        SettingsKey.weeklyReviewReminder: .bool,
    ]

    /// As definições já escolhidas neste dispositivo (as que nunca mudaram ficam de fora).
    static func records(from defaults: UserDefaults) -> [SettingRecord] {
        keys.keys.sorted().compactMap { key in
            guard defaults.object(forKey: key) != nil, let kind = keys[key] else { return nil }
            let value: RawJSON? = switch kind {
            case .double: .number(Decimal.from(defaults.double(forKey: key)))
            case .int: .number(Decimal(defaults.integer(forKey: key)))
            case .bool: .bool(defaults.bool(forKey: key))
            case .string: defaults.string(forKey: key).map(RawJSON.string)
            }
            return value.map { SettingRecord(key: key, value: $0) }
        }
    }

    /// Grava as definições recebidas (de outro dispositivo ou de uma cópia).
    /// Chaves desconhecidas ou com o tipo errado são ignoradas.
    @discardableResult
    static func apply(_ records: [SettingRecord], to defaults: UserDefaults) -> Int {
        var changed = 0
        for record in records {
            guard let kind = keys[record.key] else { continue }
            switch (kind, record.value) {
            case let (.double, .number(number)):
                defaults.set(number.doubleValue, forKey: record.key)
            case let (.int, .number(number)):
                defaults.set(Int(number.doubleValue.rounded()), forKey: record.key)
            case let (.bool, .bool(flag)):
                defaults.set(flag, forKey: record.key)
            case let (.string, .string(text)):
                defaults.set(text, forKey: record.key)
            default:
                continue
            }
            changed += 1
        }
        return changed
    }

    /// Volta a pôr os valores por omissão (a definição foi apagada noutro dispositivo).
    @discardableResult
    static func remove(keys removed: Set<String>, from defaults: UserDefaults) -> Int {
        let known = removed.filter { keys[$0] != nil }
        known.forEach(defaults.removeObject(forKey:))
        return known.count
    }
}
