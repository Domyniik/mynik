import SwiftData
import SwiftUI

/// Criar ou editar um investimento.
struct InvestmentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter
    @Environment(\.dismiss) private var dismiss

    private let investment: Investment?

    @State private var name: String
    @State private var kind: InvestmentKind
    @State private var ticker: String
    @State private var currencyCode: String
    @State private var units: Double
    @State private var investedAmount: Decimal
    @State private var manualValue: Decimal
    @State private var notes: String
    @State private var tickerCheck: String?
    @State private var isChecking = false

    init(investment: Investment? = nil) {
        self.investment = investment
        _name = State(initialValue: investment?.name ?? "")
        _kind = State(initialValue: investment?.kind ?? .etf)
        _ticker = State(initialValue: investment?.ticker ?? "")
        _currencyCode = State(initialValue: investment?.currencyCode ?? Currency.defaultCode)
        _units = State(initialValue: investment?.units ?? 0)
        _investedAmount = State(initialValue: investment?.investedAmount ?? 0)
        _manualValue = State(initialValue: investment?.manualValue ?? 0)
        _notes = State(initialValue: investment?.notes ?? "")
    }

    private var usesQuotes: Bool { kind.hasQuotes && !ticker.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (ex.: Vanguard All-World)", text: $name)
                    Picker("Tipo", selection: $kind.animation()) {
                        ForEach(InvestmentKind.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
                    }
                    Picker("Moeda", selection: $currencyCode) {
                        ForEach(Currency.supportedCodes, id: \.self) { Text($0).tag($0) }
                    }
                }
                if kind.hasQuotes {
                    Section {
                        HStack {
                            TextField("Ticker (ex.: VWCE.DE, BTC-EUR)", text: $ticker)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.characters)
                                #endif
                            Button("Verificar") { Task { await checkTicker() } }
                                .disabled(ticker.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                        }
                        if usesQuotes {
                            UnitDecimalField(title: "Unidades", value: $units, unit: "un.")
                        }
                    } header: {
                        Text("Cotação")
                    } footer: {
                        Text(tickerCheck ?? "O símbolo da Yahoo Finance. Com ticker, o valor atual é calculado com a cotação do dia; sem ticker, escreves o valor à mão.")
                    }
                }
                Section {
                    AmountField(title: "Total investido", value: $investedAmount, currencyCode: currencyCode)
                    if !usesQuotes {
                        AmountField(title: "Valor atual", value: $manualValue, currencyCode: currencyCode)
                    }
                } footer: {
                    Text("Os aportes seguintes registam-se com \"Aportar\" na lista.")
                }
                Section("Notas") {
                    TextField("Corretora, conta…", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(investment == nil ? "Novo investimento" : "Editar investimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private func checkTicker() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let quote = try await QuoteService.fetch(symbol: ticker)
            if name.trimmingCharacters(in: .whitespaces).isEmpty, let quoteName = quote.name { name = quoteName }
            tickerCheck = "✓ \(quote.name ?? ticker.uppercased()): \(quote.price.formatted(.number.precision(.fractionLength(2...4)).locale(.app))) \(quote.currency)"
        } catch {
            tickerCheck = "Não encontrei \"\(ticker.uppercased())\". Confirma o símbolo na Yahoo Finance (ex.: VWCE.DE, AAPL, BTC-EUR)."
        }
    }

    private func save() async {
        let target = investment ?? Investment(name: "", kind: kind)
        let tickerChanged = target.ticker != ticker.trimmingCharacters(in: .whitespaces).uppercased()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.kind = kind
        target.ticker = kind.hasQuotes ? ticker.trimmingCharacters(in: .whitespaces).uppercased() : ""
        target.currencyCode = currencyCode
        target.units = target.usesQuotes ? max(0, units) : 0
        target.investedAmount = max(0, investedAmount)
        target.manualValue = target.usesQuotes ? 0 : max(0, manualValue)
        target.notes = notes
        if investment == nil { modelContext.insert(target) }
        if target.usesQuotes, tickerChanged || target.unitPrice == 0 {
            target.priceUpdatedAt = nil
            await InvestmentService.refreshQuotes([target], converter: converter, force: true)
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Registar um aporte (dinheiro novo) num investimento.
struct ContributionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt) private var accounts: [Account]

    let investment: Investment

    @State private var amount: Decimal = 0
    @State private var units: Double = 0
    @State private var date = Date.now
    @State private var postToFinance = true
    @State private var account: Account?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(title: "Valor", value: $amount, currencyCode: investment.currencyCode)
                    if investment.usesQuotes {
                        UnitDecimalField(title: "Unidades compradas", value: $units, unit: "un.")
                    }
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
                Section {
                    Toggle("Sai de uma conta (lança nas Finanças)", isOn: $postToFinance.animation())
                    if postToFinance {
                        Picker("Conta", selection: $account) {
                            ForEach(accounts) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                } footer: {
                    Text("Entra na categoria \"Investimentos\" e conta como poupança na meta mensal.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Aportar · \(investment.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        InvestmentService.contribute(
                            amount, units: units, to: investment, account: account,
                            postToFinance: postToFinance, date: date, in: modelContext
                        )
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
            .onAppear { account = account ?? accounts.first }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }
}
