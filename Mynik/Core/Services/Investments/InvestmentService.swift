import Foundation
import SwiftData

/// Aportes, cotações e fotografias diárias do património.
enum InvestmentService {
    static let categoryName = "Investimentos"
    static let externalIDPrefix = "investment-contribution-"
    /// Cotações com mais de 6 horas são atualizadas ao abrir o ecrã.
    static let quoteMaximumAge: TimeInterval = 6 * 60 * 60

    /// Regista um aporte: soma ao investido (e às unidades) e, se pedido,
    /// lança a saída de dinheiro nas Finanças (categoria "Investimentos").
    @discardableResult
    static func contribute(
        _ amount: Decimal,
        units: Double = 0,
        to investment: Investment,
        account: Account?,
        postToFinance: Bool,
        date: Date = .now,
        in context: ModelContext
    ) -> FinanceTransaction? {
        guard amount > 0 else { return nil }
        investment.investedAmount += amount
        investment.units += max(0, units)
        if !investment.usesQuotes {
            investment.manualValue += amount
        }
        guard postToFinance else { return nil }
        let transaction = FinanceTransaction(
            title: "Aporte · \(investment.name)",
            amount: amount,
            kind: .expense,
            date: date,
            currencyCode: investment.currencyCode,
            category: investmentsCategory(in: context),
            account: account
        )
        transaction.externalID = externalIDPrefix + UUID().uuidString
        context.insert(transaction)
        return transaction
    }

    /// Categoria "Investimentos" (criada na primeira vez que é precisa).
    static func investmentsCategory(in context: ModelContext) -> Category {
        let name = categoryName
        if let existing = try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })).first {
            return existing
        }
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        let category = Category(name: name, symbolName: "chart.line.uptrend.xyaxis", color: .mint, kind: .expense, sortOrder: count)
        context.insert(category)
        return category
    }

    /// Atualiza as cotações das posições com ticker. Devolve os tickers que falharam.
    @discardableResult
    static func refreshQuotes(
        _ investments: [Investment],
        converter: CurrencyConverter,
        force: Bool = false,
        session: URLSession = .shared,
        now: Date = .now
    ) async -> [String] {
        var failed: [String] = []
        var rates: [String: Decimal] = [:]
        for investment in investments where investment.usesQuotes && !investment.isArchived {
            if !force, let updated = investment.priceUpdatedAt, now.timeIntervalSince(updated) < quoteMaximumAge {
                continue
            }
            do {
                let quote = try await QuoteService.fetch(symbol: investment.ticker, session: session)
                let price = try await convert(quote, to: investment.currencyCode, converter: converter, rates: &rates, session: session)
                investment.unitPrice = price
                investment.priceUpdatedAt = now
            } catch {
                // Sem rede ou ticker errado: fica a última cotação guardada.
                failed.append(investment.ticker)
            }
        }
        return failed
    }

    private static func convert(
        _ quote: Quote,
        to target: String,
        converter: CurrencyConverter,
        rates: inout [String: Decimal],
        session: URLSession
    ) async throws -> Decimal {
        if quote.currency == target { return quote.price }
        if Currency.supportedCodes.contains(quote.currency) {
            return converter.convert(quote.price, from: quote.currency, to: target)
        }
        // Outras moedas (USD, GBP...): taxa do dia para EUR e daí para a moeda do investimento.
        let rate: Decimal
        if let cached = rates[quote.currency] {
            rate = cached
        } else {
            rate = try await QuoteService.rate(from: quote.currency, to: Currency.defaultCode, session: session)
            rates[quote.currency] = rate
        }
        return converter.convert(quote.price * rate, from: Currency.defaultCode, to: target)
    }

    /// Guarda (ou atualiza) a fotografia de hoje do património.
    @discardableResult
    static func recordSnapshot(in context: ModelContext, converter: CurrencyConverter, now: Date = .now, calendar: Calendar = .current) -> WealthSnapshot? {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let investments = (try? context.fetch(FetchDescriptor<Investment>())) ?? []
        guard !investments.isEmpty || accounts.contains(where: { !($0.transactions ?? []).isEmpty }) else { return nil }

        let summary = WealthSummary(accounts: accounts, investments: investments, converter: converter)
        let day = calendar.startOfDay(for: now)
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let descriptor = FetchDescriptor<WealthSnapshot>(predicate: #Predicate { $0.day >= day && $0.day < next })
        let snapshot = (try? context.fetch(descriptor).first) ?? {
            let snapshot = WealthSnapshot(day: day)
            context.insert(snapshot)
            return snapshot
        }()
        snapshot.cash = summary.cash
        snapshot.invested = summary.invested
        snapshot.investmentsValue = summary.investmentsValue
        return snapshot
    }
}
