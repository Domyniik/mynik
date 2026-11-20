import Foundation
import SwiftData

/// Resumos em texto dos dados do utilizador, lidos do SwiftData.
///
/// São a "fonte da verdade" do chat: as ferramentas do Foundation Models chamam-nos
/// e o modo sem IA mostra-os diretamente. Todos os valores em EUR.
@MainActor
struct MynikDataDigest {
    let context: ModelContext
    var converter = CurrencyConverter()
    var now: Date = .now
    var calendar: Calendar = .current
    var defaults: UserDefaults = AppEnvironment.defaults

    // MARK: - Finanças

    /// Receitas, gastos, saldo e principais categorias de um mês (0 = este, 1 = o anterior...).
    func finances(monthsAgo: Int = 0) -> String {
        let month = monthDate(monthsAgo)
        let transactions = fetch(FetchDescriptor<FinanceTransaction>())
        let summary = MonthSummary(month: month, transactions: transactions, converter: converter, calendar: calendar)
        let slices = FinanceReport.expensesByCategory(month: month, transactions: transactions, converter: converter, calendar: calendar)
        var lines = [
            "Finanças de \(monthName(month)):",
            "- Receitas: \(money(summary.income))",
            "- Gastos: \(money(summary.expenses))",
            "- Saldo: \(money(summary.balance))",
        ]
        if slices.isEmpty {
            lines.append("- Sem gastos registados neste mês.")
        } else {
            lines.append("- Gastos por categoria: " + slices.prefix(6).map { "\($0.name) \(money($0.amount))" }.joined(separator: "; "))
        }
        let overBudget = budgetOverruns(month: month, transactions: transactions)
        if !overBudget.isEmpty {
            lines.append("- Acima do orçamento: " + overBudget.joined(separator: "; "))
        }
        return lines.joined(separator: "\n")
    }

    /// Quanto se gastou numa categoria ou num comerciante num mês.
    func spending(matching query: String, monthsAgo: Int = 0) -> String {
        let key = query.searchKey
        guard !key.isEmpty else { return finances(monthsAgo: monthsAgo) }
        let month = monthDate(monthsAgo)
        let matches = fetch(FetchDescriptor<FinanceTransaction>()).filter { transaction in
            transaction.kind == .expense
                && calendar.isDate(transaction.date, equalTo: month, toGranularity: .month)
                && (transaction.category?.name.searchKey == key || transaction.title.searchKey.contains(key))
        }
        guard !matches.isEmpty else {
            return "Não há gastos com \(query) em \(monthName(month))."
        }
        let total = matches.reduce(Decimal(0)) { $0 + converter.amountInDefaultCurrency($1) }
        let biggest = matches.max { converter.amountInDefaultCurrency($0) < converter.amountInDefaultCurrency($1) }
        // Mostra o nome da categoria como está escrito ("Alimentação", não "alimentacao").
        let label = matches.lazy.compactMap(\.category).first { $0.name.searchKey == key }?.name ?? query
        var text = "Gastos com \(label) em \(monthName(month)): \(money(total)) em \(matches.count) movimento(s)."
        if let biggest {
            text += " O maior: \(biggest.title), \(money(converter.amountInDefaultCurrency(biggest))) a \(day(biggest.date))."
        }
        return text
    }

    // MARK: - Contas a pagar

    func bills(days: Int = 30) -> String {
        let limit = calendar.date(byAdding: .day, value: max(1, days), to: calendar.startOfDay(for: now)) ?? now
        let pending = fetch(FetchDescriptor<Bill>(sortBy: [SortDescriptor(\.dueDate)]))
            .filter { !$0.isPaid && $0.dueDate < limit }
        guard !pending.isEmpty else { return "Não há contas por pagar nos próximos \(days) dias." }
        let total = pending.reduce(Decimal(0)) { $0 + converter.convert($1.amount, from: $1.currencyCode) }
        let today = calendar.startOfDay(for: now)
        let lines = pending.prefix(10).map { bill in
            let overdue = bill.dueDate < today ? " (em atraso)" : ""
            return "- \(bill.title): \(money(converter.convert(bill.amount, from: bill.currencyCode))), vence a \(day(bill.dueDate))\(overdue)"
        }
        return (["Contas por pagar nos próximos \(days) dias (total \(money(total))):"] + lines).joined(separator: "\n")
    }

    // MARK: - Loja

    func store(period: StorePeriod = .week) -> String {
        let orders = fetch(FetchDescriptor<StoreOrder>())
        guard !orders.isEmpty else { return "A loja ainda não tem pedidos sincronizados." }
        let metrics = StoreMetrics(
            orders: orders,
            stats: fetch(FetchDescriptor<DailyStat>()),
            products: fetch(FetchDescriptor<StoreProduct>()),
            costs: StoreCostSettings(defaults: defaults),
            calendar: calendar
        )
        let kpis = metrics.kpis(for: period, now: now)
        var lines = [
            "Loja — \(period.title):",
            "- Vendas: \(money(kpis.current.sales)) (\(change(StoreKPIs.change(kpis.current.sales, kpis.previous.sales))) \(period.comparisonTitle))",
            "- Pedidos: \(kpis.current.orders)",
            "- Lucro real: \(money(kpis.current.profit))",
        ]
        if let average = kpis.current.averageOrderValue {
            lines.append("- Ticket médio: \(money(average))")
        }
        if let conversion = kpis.current.conversionRate {
            lines.append("- Conversão: \(conversion.formatted(.percent.precision(.fractionLength(1)).locale(.app)))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Vida

    func life(topic: LifeTopic) -> String {
        switch topic {
        case .car: car()
        case .goals: goals()
        case .wealth: wealth()
        case .agenda, .documents, .career: agenda(topic: topic)
        }
    }

    private func car() -> String {
        let vehicles = fetch(FetchDescriptor<Vehicle>())
        guard !vehicles.isEmpty else { return "Ainda não há nenhum carro registado." }
        return vehicles.map { vehicle in
            let economy = FuelEconomy(entries: vehicle.fuelEntries ?? [])
            let monthFuel = (vehicle.fuelEntries ?? [])
                .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
                .reduce(Decimal(0)) { $0 + converter.convert($1.totalCost, from: $1.currencyCode) }
            var text = "\(vehicle.displayName): \(vehicle.currentOdometer.formatted(.number.locale(.app))) km"
            if let average = economy.averagePer100km {
                text += ", consumo médio \(average.formatted(.number.precision(.fractionLength(1)).locale(.app))) \(vehicle.fuelType.unit)/100 km"
            }
            text += ", combustível este mês \(money(monthFuel))."
            let deadlines = LifeAgenda.carItems([vehicle], now: now).upcoming(from: now, calendar: calendar)
            if let next = deadlines.first {
                text += " Próximo prazo: \(next.title) — \(next.describe(from: now, calendar: calendar))."
            }
            return text
        }.joined(separator: "\n")
    }

    private func goals() -> String {
        let goals = fetch(FetchDescriptor<Goal>()).filter { !$0.isArchived }
        guard !goals.isEmpty else { return "Não há metas ativas." }
        return (["Metas:"] + goals.map { goal in
            let progress = GoalProgress(goal: goal, converter: converter, now: now, calendar: calendar)
            var text = "- \(goal.title): \(money(progress.current)) de \(money(progress.target)) (\(progress.fraction.formatted(.percent.precision(.fractionLength(0)).locale(.app))))"
            if let monthly = progress.monthlyNeeded, !progress.isReached {
                text += ", faltam \(money(monthly)) por mês"
            }
            return text
        }).joined(separator: "\n")
    }

    private func wealth() -> String {
        let summary = WealthSummary(
            accounts: fetch(FetchDescriptor<Account>()),
            investments: fetch(FetchDescriptor<Investment>()),
            converter: converter
        )
        return """
            Património: \(money(summary.netWorth)) (contas \(money(summary.cash)), \
            investimentos \(money(summary.investmentsValue)), investido \(money(summary.invested)), \
            ganho \(money(summary.gain))).
            """
    }

    private func agenda(topic: LifeTopic) -> String {
        let source: AgendaItem.Source? = switch topic {
        case .documents: .document
        case .career: .career
        default: nil
        }
        let items = LifeAgenda.allItems(in: context, now: now)
            .filter { source == nil || $0.source == source }
            .upcoming(from: now, calendar: calendar)
        guard !items.isEmpty else { return "Não há prazos próximos de \(topic.title.lowercased())." }
        return (["Próximos prazos (\(topic.title.lowercased())):"] + items.prefix(8).map {
            "- \($0.title): \($0.describe(from: now, calendar: calendar))"
        }).joined(separator: "\n")
    }

    // MARK: - Ajudas

    private func budgetOverruns(month: Date, transactions: [FinanceTransaction]) -> [String] {
        let categories = fetch(FetchDescriptor<Category>()).filter { $0.monthlyBudget > 0 }
        let spent = FinanceReport.expensesByCategory(month: month, transactions: transactions, converter: converter, calendar: calendar)
        return categories.compactMap { category in
            guard let amount = spent.first(where: { $0.name == category.name })?.amount, amount > category.monthlyBudget else { return nil }
            return "\(category.name) \(money(amount)) de \(money(category.monthlyBudget))"
        }
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    private func monthDate(_ monthsAgo: Int) -> Date {
        calendar.date(byAdding: .month, value: -max(0, monthsAgo), to: now) ?? now
    }

    private func monthName(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(.app))
    }

    private func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(.app))
    }

    private func money(_ amount: Decimal) -> String {
        Currency.format(amount)
    }

    private func change(_ value: Double?) -> String {
        guard let value else { return "sem comparação" }
        return value.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()).locale(.app))
    }
}

/// Temas da "vida" que o chat sabe consultar.
nonisolated enum LifeTopic: String, CaseIterable, Sendable {
    case car = "carro"
    case documents = "documentos"
    case career = "carreira"
    case goals = "metas"
    case wealth = "patrimonio"
    case agenda = "agenda"

    var title: String {
        switch self {
        case .car: "Carro"
        case .documents: "Documentos"
        case .career: "Carreira"
        case .goals: "Metas"
        case .wealth: "Património"
        case .agenda: "Agenda"
        }
    }
}
