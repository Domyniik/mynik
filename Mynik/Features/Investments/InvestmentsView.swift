import SwiftData
import SwiftUI

/// Património: valor total, evolução, meta de poupança e investimentos.
struct InvestmentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \Investment.createdAt) private var investments: [Investment]
    @Query private var accounts: [Account]
    @Query(sort: \WealthSnapshot.day) private var snapshots: [WealthSnapshot]

    @State private var isAdding = false
    @State private var editing: Investment?
    @State private var contributingTo: Investment?
    @State private var isRefreshing = false
    @State private var failedTickers: [String] = []

    private var active: [Investment] { investments.filter { !$0.isArchived } }
    private var archived: [Investment] { investments.filter(\.isArchived) }

    var body: some View {
        let summary = WealthSummary(accounts: accounts, investments: investments, converter: converter)
        List {
            WealthHeaderSection(summary: summary)
            WealthChartSection(snapshots: snapshots)
            SavingsSection()

            Section {
                if active.isEmpty {
                    Button("Adicionar investimento", systemImage: "plus.circle") { isAdding = true }
                }
                ForEach(active) { investment in
                    row(investment)
                }
            } header: {
                Text("Investimentos")
            } footer: {
                quotesFooter
            }

            if !archived.isEmpty {
                Section("Arquivados") {
                    ForEach(archived) { row($0) }
                }
            }
        }
        .navigationTitle("Património")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Novo investimento", systemImage: "plus") { isAdding = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            if active.contains(where: \.usesQuotes) {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Atualizar cotações", systemImage: "arrow.clockwise") {
                        Task { await refresh(force: true) }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .refreshable { await refresh(force: true) }
        .task { await refresh(force: false) }
        .sheet(isPresented: $isAdding) { InvestmentFormView() }
        .sheet(item: $editing) { InvestmentFormView(investment: $0) }
        .sheet(item: $contributingTo) { ContributionSheet(investment: $0) }
    }

    private func row(_ investment: Investment) -> some View {
        Button { editing = investment } label: {
            InvestmentRow(investment: investment)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button("Aportar", systemImage: "plus") { contributingTo = investment }
                .tint(.green)
        }
        .swipeActions {
            Button("Apagar", systemImage: "trash", role: .destructive) { delete(investment) }
        }
        .contextMenu {
            Button("Aportar", systemImage: "plus") { contributingTo = investment }
            Button(investment.isArchived ? "Reativar" : "Arquivar", systemImage: "archivebox") {
                investment.isArchived.toggle()
                save()
            }
            Button("Apagar", systemImage: "trash", role: .destructive) { delete(investment) }
        }
    }

    @ViewBuilder
    private var quotesFooter: some View {
        if isRefreshing {
            Text("A atualizar cotações…")
        } else if !failedTickers.isEmpty {
            Text("Sem cotação para \(failedTickers.joined(separator: ", ")): a mostrar o último valor guardado.")
        } else if active.contains(where: \.usesQuotes) {
            Text("Cotações da Yahoo Finance (podem ter atraso). Desliza para a direita para registar um aporte.")
        }
    }

    private func refresh(force: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        failedTickers = await InvestmentService.refreshQuotes(investments, converter: converter, force: force)
        isRefreshing = false
        InvestmentService.recordSnapshot(in: modelContext, converter: converter)
        save()
    }

    private func delete(_ investment: Investment) {
        withAnimation {
            modelContext.delete(investment)
            save()
        }
    }

    private func save() {
        try? modelContext.save()
    }
}

/// Património líquido em destaque, com contas, investido e ganho.
struct WealthHeaderSection: View {
    let summary: WealthSummary

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Património líquido").font(.subheadline).foregroundStyle(.secondary)
                Text(Currency.format(summary.netWorth))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.vertical, 4)
            LabeledContent("Nas contas") { Text(Currency.format(summary.cash)).monospacedDigit() }
            LabeledContent("Investimentos") { Text(Currency.format(summary.investmentsValue)).monospacedDigit() }
            LabeledContent("Total investido") { Text(Currency.format(summary.invested)).monospacedDigit() }
            if summary.invested > 0 {
                LabeledContent("Ganho") {
                    GainText(gain: summary.gain, fraction: summary.gainFraction)
                }
            }
        }
    }
}

/// "+120,00 € (+8 %)", a verde ou vermelho.
struct GainText: View {
    let gain: Decimal
    let fraction: Double?
    var currencyCode = Currency.defaultCode

    var body: some View {
        let sign = gain >= 0 ? "+" : ""
        let percent = fraction.map { " (\(sign)\($0.formatted(.percent.precision(.fractionLength(1)).locale(.app))))" } ?? ""
        Text("\(sign)\(Currency.format(gain, code: currencyCode))\(percent)")
            .monospacedDigit()
            .foregroundStyle(gain >= 0 ? .green : .red)
    }
}

struct InvestmentRow: View {
    let investment: Investment

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: investment.kind.symbolName, color: .mint)
            VStack(alignment: .leading, spacing: 2) {
                Text(investment.name).lineLimit(1)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Currency.format(investment.currentValue, code: investment.currencyCode))
                    .monospacedDigit()
                if investment.investedAmount > 0 {
                    GainText(gain: investment.gain, fraction: investment.gainFraction, currencyCode: investment.currencyCode)
                        .font(.caption)
                }
            }
        }
        .contentShape(.rect)
    }

    private var details: String {
        var parts = [investment.kind.title]
        if investment.usesQuotes {
            parts.append(investment.ticker.uppercased())
            parts.append("\(investment.units.formatted(.number.precision(.fractionLength(0...4)).locale(.app))) un.")
            if let updated = investment.priceUpdatedAt {
                parts.append(updated.formatted(.relative(presentation: .named).locale(.app)))
            }
        }
        return parts.joined(separator: " · ")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        InvestmentsView()
    }
}
