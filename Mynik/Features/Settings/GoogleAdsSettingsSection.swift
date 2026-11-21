import SwiftData
import SwiftUI

/// Ligação ao gasto do Google Ads através de uma folha do Google Sheets.
struct GoogleAdsSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSyncCoordinator.self) private var storeSync

    @AppStorage(SettingsKey.googleAdsSheet) private var sheet = ""
    @AppStorage(SettingsKey.googleAdsTotal30d) private var total30d = 0.0
    @AppStorage(SettingsKey.googleAdsLastImport) private var lastImport = 0.0

    @State private var isImporting = false

    private var isValid: Bool { GoogleAdsSpendImporter.sheetID(from: sheet) != nil }

    var body: some View {
        Section {
            TextField("Folha do Google Sheets", text: $sheet, prompt: Text("https://docs.google.com/spreadsheets/d/…"))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif

            if lastImport > 0 {
                LabeledContent("Gasto nos últimos 30 dias") {
                    Text(Currency.format(Decimal.from(total30d)))
                        .monospacedDigit()
                }
                LabeledContent("Atualizado") {
                    Text(Date(timeIntervalSince1970: lastImport), format: .relative(presentation: .named))
                }
            }

            if let warning = storeSync.adsWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            Button("Atualizar agora", systemImage: "arrow.clockwise") {
                Task {
                    isImporting = true
                    await storeSync.importGoogleAdsSpend(in: modelContext)
                    isImporting = false
                }
            }
            .disabled(!isValid || isImporting)
        } header: {
            ListSectionHeader("Google Ads", systemImage: "megaphone", color: .blue)
        } footer: {
            Text("O script em scripts/google-ads/export-ad-spend.js escreve o gasto diário nesta folha. O gasto de anúncios que apontam para um produto vai para esse produto (ROAS); o resto entra nos anúncios gerais do lucro real. Atualiza com a loja.")
        }
    }
}
