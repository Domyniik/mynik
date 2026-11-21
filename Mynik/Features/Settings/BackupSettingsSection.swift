import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Cópia de segurança em JSON: substitui o sync por iCloud entre dispositivos.
struct BackupSettingsSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportedFile: ExportedBackup?
    @State private var isExporterPresented = false
    @State private var isImporterPresented = false
    @State private var pendingImport: BackupArchive?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Button("Criar cópia de segurança", systemImage: "externaldrive.badge.plus") {
                Task { await prepareExport() }
            }

            if let exportedFile {
                ShareLink(item: exportedFile.url) {
                    Label("Enviar por AirDrop, iCloud Drive…", systemImage: "square.and.arrow.up")
                }
                // Cada seletor de ficheiros no seu botão: dois na mesma vista não abrem no iOS.
                Button("Guardar em Ficheiros…", systemImage: "folder") {
                    isExporterPresented = true
                }
                .fileExporter(
                    isPresented: $isExporterPresented,
                    document: JSONFileDocument(data: exportedFile.data),
                    contentType: .json,
                    defaultFilename: exportedFile.url.lastPathComponent
                ) { result in
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    } else {
                        statusMessage = "Cópia guardada."
                    }
                }
            }

            Button("Importar cópia…", systemImage: "square.and.arrow.down") {
                isImporterPresented = true
            }
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.json]) { result in
                readImport(result)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            ListSectionHeader("Cópia de segurança e sincronização", systemImage: "externaldrive.badge.icloud", color: .cyan)
        } footer: {
            Text("Sem iCloud: cria uma cópia num dispositivo e importa-a no outro. A importação junta os dados sem duplicar — o que é novo é acrescentado, o que já existe fica com a versão do ficheiro e nada é apagado. A cópia inclui os documentos: guarda-a num sítio seguro.")
        }
        .confirmationDialog(
            "Importar cópia?",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible,
            presenting: pendingImport
        ) { archive in
            Button("Importar \(archive.recordCount) registos") { apply(archive) }
            Button("Cancelar", role: .cancel) {}
        } message: { archive in
            Text(importMessage(for: archive))
        }
    }

    // MARK: - Ações

    private func prepareExport() async {
        errorMessage = nil
        statusMessage = nil
        // Os números e as fotos dos documentos estão protegidos: pede a mesma autenticação.
        if BackupService.containsDocuments(in: modelContext) {
            await BiometricLock.shared.unlock(reason: "Criar uma cópia de segurança com os teus documentos")
            guard BiometricLock.shared.isUnlocked else {
                errorMessage = BiometricLock.shared.message ?? "É preciso confirmar a tua identidade para exportar os documentos."
                return
            }
        }
        do {
            let archive = try BackupService.makeArchive(from: modelContext)
            let data = try archive.encoded()
            let url = URL.temporaryDirectory.appending(path: archive.suggestedFileName)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            exportedFile = ExportedBackup(url: url, data: data)
            statusMessage = "\(archive.recordCount) registos · \(data.count.formatted(.byteCount(style: .file)))"
        } catch {
            errorMessage = "Não foi possível criar a cópia: \(error.localizedDescription)"
        }
    }

    private func readImport(_ result: Result<URL, any Error>) {
        errorMessage = nil
        statusMessage = nil
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try BackupArchive.decode(Data(contentsOf: url))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ archive: BackupArchive) {
        do {
            let summary = try BackupService.importArchive(archive, into: modelContext)
            statusMessage = summary.description
        } catch {
            modelContext.rollback()
            errorMessage = "Não foi possível importar: \(error.localizedDescription)"
        }
        pendingImport = nil
    }

    private func importMessage(for archive: BackupArchive) -> String {
        let date = archive.exportedAt.formatted(date: .abbreviated, time: .shortened)
        let origin = archive.device.isEmpty ? "" : " em \(archive.device)"
        return "Cópia de \(date)\(origin). Os dados são juntados aos teus: nada é apagado."
    }
}

private struct ExportedBackup {
    let url: URL
    let data: Data
}

/// Ficheiro JSON para o `fileExporter`.
nonisolated struct JSONFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview(traits: .sampleData) {
    Form {
        BackupSettingsSection()
    }
}
