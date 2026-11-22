import SwiftData
import SwiftUI

/// Busca global (⌘K): movimentos, contas, notas, projetos, metas, hábitos, carro, documentos...
struct GlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var editingTransaction: FinanceTransaction?
    @State private var isSearchPresented = false

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    Text("Escreve pelo menos duas letras: um gasto, uma nota, um projeto, uma secção…")
                        .foregroundStyle(.secondary)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(results) { result in
                        Button { open(result) } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title).foregroundStyle(.primary)
                                    Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: result.symbolName)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pesquisar")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, isPresented: $isSearchPresented, prompt: "Pesquisar no Mynik")
            .onSubmit(of: .search) {
                if let first = results.first { open(first) }
            }
            .task(id: query) {
                // Pequena pausa para não procurar a cada tecla.
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                results = GlobalSearch.search(query, in: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", systemImage: "xmark") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .task {
                // Abre já com o teclado no campo de pesquisa.
                try? await Task.sleep(for: .milliseconds(300))
                isSearchPresented = true
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionFormView(transaction: transaction)
            }
        }
    }

    private func open(_ result: SearchResult) {
        switch result.target {
        case .section(let section):
            router.open(section)
            dismiss()
        case .transaction(let id):
            editingTransaction = modelContext.model(for: id) as? FinanceTransaction
        }
    }
}
