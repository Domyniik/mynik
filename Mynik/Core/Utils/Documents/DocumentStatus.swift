import Foundation

/// Estado da validade de um documento.
nonisolated enum DocumentStatus: Int, Comparable, Sendable {
    case expired
    case expiringSoon
    case valid
    case noExpiry

    var title: String {
        switch self {
        case .expired: "Expirados"
        case .expiringSoon: "A expirar"
        case .valid: "Válidos"
        case .noExpiry: "Sem validade"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// "A expirar" quando faltam `remindDaysBefore` dias ou menos.
    static func of(expiry: Date?, remindDaysBefore: Int, now: Date = .now, calendar: Calendar = .current) -> Self {
        guard let expiry else { return .noExpiry }
        let days = DueDateText.daysUntil(expiry, from: now, calendar: calendar)
        if days < 0 { return .expired }
        return days <= remindDaysBefore ? .expiringSoon : .valid
    }

    /// "Expira em 12 dias", "Expirou há 3 dias", "Válido até 3 mar 2029".
    static func describe(expiry: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let expiry else { return "Sem validade" }
        let days = DueDateText.daysUntil(expiry, from: now, calendar: calendar)
        switch days {
        case ..<(-1): return "Expirou há \(-days) dias"
        case -1: return "Expirou ontem"
        case 0: return "Expira hoje"
        case 1: return "Expira amanhã"
        case 2...90: return "Expira em \(days) dias"
        default: return "Válido até \(expiry.formatted(.dateTime.day().month(.abbreviated).year().locale(.app)))"
        }
    }
}

nonisolated enum DocumentNumber {
    /// Esconde o número, deixando só os últimos 3 caracteres ("•••• 45Z").
    static func masked(_ number: String) -> String {
        let trimmed = number.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 3 else { return trimmed.isEmpty ? "" : "••••" }
        return "•••• " + trimmed.suffix(3)
    }
}
