import Foundation
import SwiftData

/// Lê o gasto do Google Ads de uma folha do Google Sheets.
///
/// A folha é preenchida todos os dias pelo script `scripts/google-ads/export-ad-spend.js`
/// (colunas `date,campaign,cost,currency,final_url`) e partilhada como "qualquer
/// pessoa com o link pode ver", o que permite lê-la em CSV sem login nem chaves.
/// O gasto de anúncios cujo URL final aponta para `/products/<handle>` vai para
/// esse produto; o resto entra nos anúncios gerais.
nonisolated enum GoogleAdsSpendImporter {
    struct Row: Equatable, Sendable {
        var date: String
        var campaign: String
        var cost: Decimal
        var currency: String
        var finalURL: String
    }

    struct Summary: Equatable, Sendable {
        /// Gasto por `handle` de produto (em minúsculas), em EUR.
        var perProductHandle: [String: Decimal] = [:]
        /// Gasto sem produto associado, em EUR.
        var unattributed: Decimal = 0

        var total: Decimal { perProductHandle.values.reduce(unattributed, +) }
    }

    enum ImportError: LocalizedError, Equatable {
        case invalidSheet
        case notShared
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .invalidSheet:
                "O endereço da folha do Google Ads não é válido."
            case .notShared:
                "A folha do Google Ads não está partilhada com “Qualquer pessoa com o link”."
            case .badResponse(let status):
                "O Google Sheets respondeu com o erro \(status)."
            }
        }
    }

    // MARK: - Folha

    /// Aceita o URL completo da folha ou só o seu ID.
    static func sheetID(from input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "/spreadsheets/d/") {
            let id = text[range.upperBound...].prefix { $0 != "/" && $0 != "?" && $0 != "#" }
            return id.isEmpty ? nil : String(id)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard text.count >= 20, text.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return text
    }

    static func exportURL(sheetID: String) -> URL? {
        URL(string: "https://docs.google.com/spreadsheets/d/\(sheetID)/export?format=csv")
    }

    static func fetch(sheetID: String, session: URLSession = .shared) async throws -> [Row] {
        guard let url = exportURL(sheetID: sheetID) else { throw ImportError.invalidSheet }
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let mimeType = response.mimeType ?? ""
        // Uma folha privada redireciona para a página de login (HTML).
        if mimeType.contains("html") || [401, 403].contains(status) { throw ImportError.notShared }
        guard status == 200 else { throw ImportError.badResponse(status) }
        return parse(csv: String(decoding: data, as: UTF8.self))
    }

    // MARK: - CSV

    static func parse(csv: String) -> [Row] {
        let records = csvRecords(csv)
        guard let header = records.first?.map({ $0.lowercased().trimmingCharacters(in: .whitespaces) }) else { return [] }
        func index(_ name: String) -> Int? { header.firstIndex(of: name) }
        guard let date = index("date"), let cost = index("cost") else { return [] }
        let campaign = index("campaign"), currency = index("currency"), url = index("final_url")

        return records.dropFirst().compactMap { fields in
            func field(_ i: Int?) -> String {
                guard let i, i < fields.count else { return "" }
                return fields[i].trimmingCharacters(in: .whitespaces)
            }
            guard !field(date).isEmpty, let value = decimal(field(cost)) else { return nil }
            return Row(
                date: field(date),
                campaign: field(campaign),
                cost: value,
                currency: field(currency).isEmpty ? Currency.defaultCode : field(currency).uppercased(),
                finalURL: field(url)
            )
        }
    }

    /// Aceita "12.5" e "12,5" (a folha pode estar em locale português).
    private static func decimal(_ text: String) -> Decimal? {
        let normalized = text.contains(",") && !text.contains(".") ? text.replacingOccurrences(of: ",", with: ".") : text
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Divide o CSV em registos, respeitando campos entre aspas (vírgulas, aspas e quebras de linha).
    private static func csvRecords(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character?

        while let char = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
                continue
            }
            switch char {
            case "\"": inQuotes = true
            case ",": record.append(field); field = ""
            case "\n", "\r\n", "\r":
                record.append(field); field = ""
                if record != [""] { records.append(record) }
                record = []
            default: field.append(char)
            }
        }
        record.append(field)
        if record != [""] { records.append(record) }
        return records
    }

    // MARK: - Resumo

    /// Soma o gasto de `days` dias até `now` (inclusive), em EUR.
    static func summarize(
        _ rows: [Row],
        days: Int = 30,
        now: Date = .now,
        calendar: Calendar = .current,
        converter: CurrencyConverter = CurrencyConverter()
    ) -> Summary {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let fromKey = dayKey(start, calendar: calendar)
        let toKey = dayKey(today, calendar: calendar)

        var summary = Summary()
        for row in rows where row.date >= fromKey && row.date <= toKey {
            let amount = converter.convert(row.cost, from: row.currency)
            if let handle = productHandle(in: row.finalURL) {
                summary.perProductHandle[handle, default: 0] += amount
            } else {
                summary.unattributed += amount
            }
        }
        return summary
    }

    /// `https://neloce.com/products/aplique-doble?variant=1` → `aplique-doble`.
    static func productHandle(in url: String) -> String? {
        guard let path = URL(string: url)?.path, let range = path.range(of: "/products/") else { return nil }
        let handle = path[range.upperBound...].prefix { $0 != "/" }
        return handle.isEmpty ? nil : handle.lowercased()
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Aplicar

    /// Escreve o gasto nos produtos e guarda o gasto geral nas Definições.
    @MainActor
    static func apply(_ summary: Summary, to context: ModelContext, defaults: UserDefaults, now: Date = .now) throws {
        let products = try context.fetch(FetchDescriptor<StoreProduct>())
        for product in products {
            product.adSpend30d = summary.perProductHandle[product.handle.lowercased()] ?? 0
        }
        defaults.set(summary.unattributed.doubleValue, forKey: SettingsKey.googleAdsUnattributed30d)
        defaults.set(summary.total.doubleValue, forKey: SettingsKey.googleAdsTotal30d)
        defaults.set(now.timeIntervalSince1970, forKey: SettingsKey.googleAdsLastImport)
        try context.save()
    }
}
