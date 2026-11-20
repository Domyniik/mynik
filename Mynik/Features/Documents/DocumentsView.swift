import SwiftData
import SwiftUI

/// Documentos pessoais agrupados pela validade (expirados, a expirar, válidos).
struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonalDocument.createdAt) private var documents: [PersonalDocument]

    @State private var isAdding = false
    private var lock: BiometricLock { .shared }

    private var groups: [(status: DocumentStatus, documents: [PersonalDocument])] {
        Dictionary(grouping: documents) { DocumentStatus.of(expiry: $0.expiryDate, remindDaysBefore: $0.remindDaysBefore) }
            .sorted { $0.key < $1.key }
            .map { group in
                (group.key, group.value.sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) })
            }
    }

    var body: some View {
        List {
            if documents.isEmpty {
                ContentUnavailableView {
                    Label("Sem documentos", systemImage: "person.text.rectangle")
                } description: {
                    Text("Guarda o cartão de cidadão, o passaporte, a residência ou a carta de condução com a validade. Avisamos antes de expirarem e as fotos ficam protegidas por \(lock.methodName).")
                } actions: {
                    Button("Adicionar documento") { isAdding = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                LockSection(lock: lock)
            }

            ForEach(groups, id: \.status) { group in
                Section(group.status.title) {
                    ForEach(group.documents) { document in
                        NavigationLink(value: document) {
                            DocumentRow(document: document, isUnlocked: lock.isUnlocked)
                        }
                        .swipeActions {
                            Button("Apagar", systemImage: "trash", role: .destructive) { delete(document) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Documentos")
        .navigationDestination(for: PersonalDocument.self) { document in
            DocumentDetailView(document: document)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Novo documento", systemImage: "plus") { isAdding = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAdding) {
            DocumentFormView()
        }
    }

    private func delete(_ document: PersonalDocument) {
        withAnimation {
            modelContext.delete(document)
            try? modelContext.save()
        }
    }
}

/// Estado do cofre: botão para desbloquear ou para voltar a fechar.
struct LockSection: View {
    let lock: BiometricLock

    var body: some View {
        Section {
            if lock.isUnlocked {
                Button("Esconder números e fotos", systemImage: "lock") { lock.lock() }
            } else {
                Button("Mostrar com \(lock.methodName)", systemImage: lock.symbolName) {
                    Task { await lock.unlock() }
                }
            }
        } footer: {
            if let message = lock.message {
                Text(message)
            }
        }
    }
}

struct DocumentRow: View {
    let document: PersonalDocument
    let isUnlocked: Bool

    var body: some View {
        let status = DocumentStatus.of(expiry: document.expiryDate, remindDaysBefore: document.remindDaysBefore)
        HStack(spacing: 12) {
            SymbolBadge(symbolName: document.kind.symbolName, color: color(status))
            VStack(alignment: .leading, spacing: 2) {
                Text(document.displayTitle).lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(status <= .expiringSoon ? color(status) : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private var subtitle: String {
        let number = isUnlocked ? document.number : DocumentNumber.masked(document.number)
        return [number, DocumentStatus.describe(expiry: document.expiryDate)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func color(_ status: DocumentStatus) -> Color {
        switch status {
        case .expired: .red
        case .expiringSoon: .orange
        case .valid: .blue
        case .noExpiry: .gray
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        DocumentsView()
    }
}
