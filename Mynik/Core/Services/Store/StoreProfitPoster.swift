import Foundation
import SwiftData

/// Lança o lucro real de cada mês da loja nas Finanças.
///
/// Um movimento por mês, identificado por `externalID`, atualizado a cada
/// sincronização (o mês corrente vai crescendo). Lucro positivo entra como
/// receita na categoria "Loja"; prejuízo entra como gasto.
enum StoreProfitPoster {
    static let externalIDPrefix = "store-profit-"
    static let categoryName = "Loja"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.storeProfitToFinance) as? Bool ?? true
    }

    static func externalID(forMonthStarting month: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: month)
        return externalIDPrefix + String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    /// Atualiza o mês corrente e o anterior, se a cache os cobrir por inteiro.
    ///
    /// - Parameter since: início dos pedidos sincronizados; meses que começam
    ///   antes disto ficariam incompletos e não são tocados.
    @discardableResult
    static func post(
        in context: ModelContext,
        costs: StoreCostSettings,
        since: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> [FinanceTransaction] {
        let orders = try context.fetch(FetchDescriptor<StoreOrder>())
        let products = try context.fetch(FetchDescriptor<StoreProduct>())
        let metrics = StoreMetrics(orders: orders, stats: [], products: products, costs: costs, calendar: calendar)
        let category = try context.fetch(FetchDescriptor<Category>()).first { $0.name == categoryName }
        let account = try context.fetch(FetchDescriptor<Account>()).first

        guard let currentMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)
        else { return [] }

        var posted: [FinanceTransaction] = []
        for month in [previousMonth, currentMonth] where month >= calendar.startOfDay(for: since) {
            guard let interval = calendar.dateInterval(of: .month, for: month) else { continue }
            let end = min(interval.end, calendar.startOfDay(for: now).addingTimeInterval(86_400))
            let monthOrders = orders.filter { !$0.isCancelled && $0.createdAt >= interval.start && $0.createdAt < end }
            let days = max(1, calendar.dateComponents([.day], from: interval.start, to: end).day ?? 1)
            let breakdown = metrics.breakdown(for: monthOrders, days: days)

            let id = externalID(forMonthStarting: month, calendar: calendar)
            let existing = try context.fetch(FetchDescriptor<FinanceTransaction>(predicate: #Predicate { $0.externalID == id })).first
            guard existing != nil || !monthOrders.isEmpty else { continue }

            let transaction = existing ?? {
                let transaction = FinanceTransaction(title: "", amount: 0, kind: .income)
                transaction.externalID = id
                context.insert(transaction)
                return transaction
            }()
            let monthName = month.formatted(.dateTime.month(.wide).year().locale(.app))
            let isProfit = breakdown.profit >= 0
            transaction.title = isProfit ? "Lucro da loja · \(monthName)" : "Prejuízo da loja · \(monthName)"
            transaction.amount = abs(rounded(breakdown.profit))
            transaction.kind = isProfit ? .income : .expense
            transaction.currencyCode = Currency.defaultCode
            transaction.date = min(now, interval.end.addingTimeInterval(-1))
            transaction.category = isProfit ? category : nil
            transaction.account = transaction.account ?? account
            transaction.notes = """
            Lançado automaticamente pela loja (atualiza a cada sincronização). \
            Vendas \(Currency.format(breakdown.grossSales)) · \(monthOrders.count) pedidos · \
            margem \(breakdown.margin.map { $0.formatted(.percent.precision(.fractionLength(0)).locale(.app)) } ?? "—").
            """
            posted.append(transaction)
        }
        try context.save()
        return posted
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
}
