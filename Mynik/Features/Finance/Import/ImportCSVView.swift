import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Importa movimentos a partir do extrato CSV exportado pelo banco.
struct ImportCSVView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var transactions: [FinanceTransaction]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var isPickingFile = false
    @State private var preview: CSVImportPreview?
    @State private var account: Account?
    @State private var currencyCode = Currency.defaultCode
    @State private var importedCount: Int?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let importedCount {
                Section {
                    Label(
                        importedCount == 1 ? "1 movimento importado" : "\(importedCount) movimentos importados",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
            }

            Section {
                Button("Escolher ficheiro CSV", systemImage: "doc.badge.plus") {
                    isPickingFile = true
                }
            } footer: {
                Text("Exporta o extrato no site ou app do banco (CSV) e escolhe-o aqui. Movimentos repetidos são ignorados.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            if let preview {
                previewSections(preview)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Importar CSV")
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text]
        ) { result in
            load(result)
        }
        .onAppear {
            if account == nil {
                account = accounts.first
            }
        }
    }

    @ViewBuilder
    private func previewSections(_ preview: CSVImportPreview) -> some View {
        Section {
            LabeledContent("Ficheiro", value: preview.fileName)
            LabeledContent("Novos", value: "\(preview.newItems.count)")
            if preview.duplicateCount > 0 {
                LabeledContent("Já existentes", value: "\(preview.duplicateCount)")
            }
            if preview.skippedLines > 0 {
                LabeledContent("Linhas ignoradas", value: "\(preview.skippedLines)")
            }

            Picker("Conta", selection: $account) {
                Text("Sem conta").tag(Account?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(Optional(account))
                }
            }

            Picker("Moeda", selection: $currencyCode) {
                ForEach(Currency.supportedCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            Button(importButtonTitle(preview), systemImage: "square.and.arrow.down") {
                importRows(preview)
            }
            .disabled(preview.newItems.isEmpty)
        } header: {
            Text("Pré-visualização")
        }

        Section("Movimentos") {
            ForEach(preview.items) { item in
                ImportRowView(item: item, currencyCode: currencyCode)
            }
        }
    }

    private func importButtonTitle(_ preview: CSVImportPreview) -> String {
        preview.newItems.count == 1 ? "Importar 1 movimento" : "Importar \(preview.newItems.count) movimentos"
    }

    private func load(_ result: Result<URL, Error>) {
        importedCount = nil
        errorMessage = nil
        preview = nil

        do {
            let url = try result.get()
            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let parsed = try BankCSVImporter().parse(data: data)
            preview = CSVImportPreview(fileName: url.lastPathComponent, result: parsed, existing: transactions)
            if parsed.rows.isEmpty {
                errorMessage = "O ficheiro não tem movimentos que eu consiga ler."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Não foi possível abrir o ficheiro."
        }
    }

    private func importRows(_ preview: CSVImportPreview) {
        let guesser = CategoryGuesser(history: transactions)
        let rules = RuleCategorizer(in: modelContext)
        for item in preview.newItems {
            let row = item.row
            modelContext.insert(
                FinanceTransaction(
                    title: row.title,
                    amount: row.amount,
                    kind: row.kind,
                    date: row.date,
                    currencyCode: currencyCode,
                    notes: "Importado de \(preview.fileName)",
                    category: guesser.category(for: row)
                        ?? rules.category(for: row.title, kind: row.kind),
                    account: account
                )
            )
        }

        do {
            try modelContext.save()
            importedCount = preview.newItems.count
            self.preview = nil
        } catch {
            errorMessage = "Não foi possível guardar os movimentos."
        }
    }
}

private struct ImportRowView: View {
    let item: CSVImportPreview.Item
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.row.title)
                    .lineLimit(1)
                Text(item.isDuplicate ? "Já existe · não será importado" : item.row.date.formatted(.dateTime.day().month(.abbreviated).year().locale(.app)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(Currency.format(item.row.signedAmount, code: currencyCode))
                .monospacedDigit()
                .foregroundStyle(item.row.kind == .income ? .green : .primary)
        }
        .opacity(item.isDuplicate ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ImportCSVView()
    }
}
