import SwiftUI

/// Estado da sincronização: dados de exemplo, erros e última atualização.
struct StoreSyncBanner: View {
    @Environment(StoreSyncCoordinator.self) private var storeSync

    var body: some View {
        Section {
            if storeSync.isDemo {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dados de exemplo").font(.headline)
                        Text("Liga a tua loja em Definições › Loja Shopify para ver os dados reais.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "sparkles").foregroundStyle(.purple)
                }
            }

            if let error = storeSync.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            if let warning = storeSync.trafficWarning {
                Label(warning, systemImage: "chart.line.downtrend.xyaxis")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                if storeSync.isSyncing {
                    ProgressView().controlSize(.small)
                    Text("A atualizar…")
                } else if let lastSyncedAt = storeSync.lastSyncedAt {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Atualizado \(lastSyncedAt, format: .relative(presentation: .named).locale(.app))")
                } else {
                    Text("Ainda não sincronizado")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
