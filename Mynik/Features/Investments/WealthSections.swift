import Charts
import SwiftData
import SwiftUI

/// Evolução do património (líquido e investido), a partir das fotografias diárias.
struct WealthChartSection: View {
    let snapshots: [WealthSnapshot]

    var body: some View {
        Section {
            if snapshots.count < 2 {
                Label("A evolução aparece a partir de amanhã: o Mynik guarda uma fotografia do património por dia.", systemImage: "chart.xyaxis.line")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(snapshots, id: \.day) { snapshot in
                        LineMark(x: .value("Dia", snapshot.day, unit: .day), y: .value("Valor", snapshot.netWorth))
                            .foregroundStyle(by: .value("Série", "Património"))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Dia", snapshot.day, unit: .day), y: .value("Valor", snapshot.invested))
                            .foregroundStyle(by: .value("Série", "Investido"))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .chartForegroundStyleScale(["Património": Color.mint, "Investido": Color.secondary])
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .currency(code: Currency.defaultCode).precision(.fractionLength(0)).locale(.app))
                            }
                        }
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("Evolução do património")
            }
        } header: {
            Text("Evolução")
        }
    }
}

/// Poupança deste mês face à meta mensal.
struct SavingsSection: View {
    @Environment(\.currencyConverter) private var converter
    @Query private var transactions: [FinanceTransaction]
    @AppStorage(SettingsKey.savingsMonthlyTarget) private var storedTarget = 0.0

    @State private var isEditingTarget = false

    init() {
        let start = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        _transactions = Query(filter: #Predicate<FinanceTransaction> { $0.date >= start })
    }

    var body: some View {
        let target = Decimal(string: String(storedTarget)) ?? 0
        let progress = SavingsProgress(month: .now, transactions: transactions, target: target, converter: converter)
        Section {
            LabeledContent("Poupado este mês") {
                Text(Currency.format(progress.saved))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(progress.saved >= 0 ? Color.primary : .red)
            }
            if let rate = progress.rate {
                LabeledContent("Taxa de poupança", value: rate.formatted(.percent.precision(.fractionLength(0)).locale(.app)))
            }
            if let fraction = progress.targetFraction {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: fraction).tint(fraction >= 1 ? .green : .mint)
                    Text(fraction >= 1
                        ? "Meta de \(Currency.format(target)) atingida 🎉"
                        : "Faltam \(Currency.format(progress.remainingToTarget)) para a meta de \(Currency.format(target))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button(target > 0 ? "Alterar meta mensal" : "Definir meta de poupança", systemImage: "target") {
                isEditingTarget = true
            }
        } header: {
            Text("Meta de poupança")
        } footer: {
            Text("Receitas menos gastos do mês. Os aportes a investimentos contam como poupança.")
        }
        .sheet(isPresented: $isEditingTarget) {
            SavingsTargetSheet(target: $storedTarget)
        }
    }
}

struct SavingsTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var target: Double
    @State private var amount: Decimal = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(title: "Poupar por mês", value: $amount)
                } footer: {
                    Text("Põe 0 para não ter meta.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Meta de poupança")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        target = NSDecimalNumber(decimal: max(0, amount)).doubleValue
                        dismiss()
                    }
                }
            }
            .onAppear { amount = Decimal(string: String(target)) ?? 0 }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 200)
        #endif
    }
}
