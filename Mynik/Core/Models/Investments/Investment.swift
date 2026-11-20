import Foundation
import SwiftData

/// Tipo de investimento.
nonisolated enum InvestmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case etf
    case stock
    case crypto
    case fund
    case deposit
    case pension
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .etf: "ETF"
        case .stock: "Ações"
        case .crypto: "Cripto"
        case .fund: "Fundo"
        case .deposit: "Depósito a prazo"
        case .pension: "Plano de pensões / PPR"
        case .other: "Outro"
        }
    }

    var symbolName: String {
        switch self {
        case .etf: "chart.pie"
        case .stock: "chart.line.uptrend.xyaxis"
        case .crypto: "bitcoinsign.circle"
        case .fund: "building.columns"
        case .deposit: "banknote"
        case .pension: "figure.walk.cane"
        case .other: "square.stack.3d.up"
        }
    }

    /// Tem cotação pública (ticker).
    var hasQuotes: Bool { self == .etf || self == .stock || self == .crypto || self == .fund }
}

/// Posição num investimento: quanto foi investido e quanto vale agora.
///
/// Com ticker, o valor é `unidades × cotação` (atualizada da internet);
/// sem ticker (depósitos, PPR...), o valor atual é escrito à mão.
@Model
final class Investment {
    var uid: String = UUID().uuidString
    var name: String = ""
    /// Símbolo da cotação, ex.: "VWCE.DE", "BTC-EUR" (vazio = valor manual).
    var ticker: String = ""
    var kindRaw: String = InvestmentKind.etf.rawValue
    var currencyCode: String = Currency.defaultCode
    var units: Double = 0
    /// Total investido (custo), na moeda do investimento.
    var investedAmount: Decimal = 0
    /// Última cotação por unidade, já na moeda do investimento.
    var unitPrice: Decimal = 0
    var priceUpdatedAt: Date?
    /// Valor atual quando não há ticker.
    var manualValue: Decimal = 0
    var isArchived: Bool = false
    var notes: String = ""
    var createdAt: Date = Date.now

    var kind: InvestmentKind {
        get { InvestmentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var usesQuotes: Bool { !ticker.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Valor atual na moeda do investimento.
    var currentValue: Decimal {
        usesQuotes && unitPrice > 0 ? Decimal(units) * unitPrice : manualValue
    }

    var gain: Decimal { currentValue - investedAmount }

    /// Rentabilidade sobre o investido (`nil` sem investimento).
    var gainFraction: Double? {
        investedAmount > 0 ? NSDecimalNumber(decimal: gain / investedAmount).doubleValue : nil
    }

    init(name: String, kind: InvestmentKind, ticker: String = "", units: Double = 0, investedAmount: Decimal = 0) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.ticker = ticker
        self.units = units
        self.investedAmount = investedAmount
    }
}

/// Fotografia diária do património (dinheiro nas contas + investimentos), em EUR.
@Model
final class WealthSnapshot {
    /// Início do dia.
    var day: Date = Date.now
    var cash: Decimal = 0
    var invested: Decimal = 0
    var investmentsValue: Decimal = 0

    var netWorth: Decimal { cash + investmentsValue }

    init(day: Date, cash: Decimal = 0, invested: Decimal = 0, investmentsValue: Decimal = 0) {
        self.day = day
        self.cash = cash
        self.invested = invested
        self.investmentsValue = investmentsValue
    }
}
