import SwiftUI

/// Taxa de câmbio EUR/BRL usada para somar tudo em euros.
struct CurrencySettingsSection: View {
    @AppStorage(SettingsKey.brlPerEUR) private var brlPerEUR = CurrencyConverter.defaultBRLPerEUR
    @AppStorage(SettingsKey.exchangeRateDate) private var rateDate = ""

    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            LabeledContent("1 EUR em BRL") {
                TextField("Taxa", value: $brlPerEUR, format: .number.precision(.fractionLength(2...4)).locale(.app))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 120)
            }

            LabeledContent("1 BRL em EUR", value: inverseText)

            Button {
                Task { await updateRate() }
            } label: {
                if isUpdating {
                    ProgressView()
                } else {
                    Label("Atualizar taxa do dia", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isUpdating)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            ListSectionHeader("Moedas", systemImage: "arrow.left.arrow.right.circle", color: .green)
        } footer: {
            Text(footerText)
        }
    }

    private var inverseText: String {
        guard brlPerEUR > 0 else { return "—" }
        return (1 / brlPerEUR).formatted(.number.precision(.fractionLength(4)).locale(.app))
    }

    private var footerText: String {
        let source = rateDate.isEmpty ? "Taxa manual." : "Taxa do BCE de \(formattedRateDate)."
        return "Os totais, orçamentos e gráficos convertem os movimentos em reais para euros. \(source)"
    }

    /// "2026-11-19" → "19/11/2026".
    private var formattedRateDate: String {
        guard let date = try? Date(rateDate, strategy: .iso8601.year().month().day()) else { return rateDate }
        return date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(.app))
    }

    private func updateRate() async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            let rate = try await ExchangeRateService.fetchLatest()
            brlPerEUR = rate.brlPerEUR
            rateDate = rate.date
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível obter a taxa. Verifica a ligação à internet."
        }
    }
}
