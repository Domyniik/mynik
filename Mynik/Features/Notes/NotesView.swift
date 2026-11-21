import SwiftData
import SwiftUI

/// Páginas de notas em árvore (com subpáginas) e pesquisa.
struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { $0.parent == nil }, sort: \Note.sortOrder) private var roots: [Note]
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Query(filter: #Predicate<Note> { $0.isFavorite }, sort: \Note.title) private var favorites: [Note]

    @State private var searchText = ""
    @State private var openedNote: Note?
    @State private var noteToDelete: Note?

    var body: some View {
        List {
            if !searchText.isEmpty {
                Section("Resultados") {
                    let results = NoteSearch.filter(allNotes, matching: searchText)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                    ForEach(results) { note in
                        row(note, showsPath: true)
                    }
                }
            } else if roots.isEmpty {
                ContentUnavailableView {
                    Label("Sem notas", systemImage: "note.text")
                } description: {
                    Text("Cria páginas com texto, títulos, listas de tarefas e imagens, e organiza-as em subpáginas.")
                } actions: {
                    Button("Nova página") { createNote() }
                        .buttonStyle(.glassProminent)
                }
            } else {
                if !favorites.isEmpty {
                    Section("Favoritos") {
                        ForEach(favorites) { note in
                            row(note, showsPath: true)
                        }
                    }
                }
                Section("Páginas") {
                    OutlineGroup(roots, children: \.childrenOrNil) { note in
                        row(note, showsPath: false)
                    }
                }
            }
        }
        .navigationTitle("Notas")
        .searchable(text: $searchText, prompt: "Procurar nas notas")
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note)
        }
        .navigationDestination(item: $openedNote) { note in
            NoteEditorView(note: note)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nova página", systemImage: "square.and.pencil") { createNote() }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .confirmationDialog(
            "Apagar \"\(noteToDelete?.displayTitle ?? "")\" e as subpáginas?",
            isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                if let noteToDelete { delete(noteToDelete) }
            }
        }
    }

    private func row(_ note: Note, showsPath: Bool) -> some View {
        NavigationLink(value: note) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .lineLimit(1)
                    if showsPath, !note.ancestors.isEmpty {
                        Text(note.ancestors.map(\.displayTitle).joined(separator: " › "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } icon: {
                Text(note.icon)
            }
        }
        .contextMenu {
            Button("Nova subpágina", systemImage: "plus") { createNote(parent: note) }
            Button(
                note.isFavorite ? "Tirar dos favoritos" : "Adicionar aos favoritos",
                systemImage: note.isFavorite ? "star.slash" : "star"
            ) { note.isFavorite.toggle() }
            Button("Apagar", systemImage: "trash", role: .destructive) { requestDelete(note) }
        }
        .swipeActions {
            Button("Apagar", systemImage: "trash", role: .destructive) { requestDelete(note) }
        }
    }

    private func createNote(parent: Note? = nil) {
        if parent == nil {
            // Novas páginas de topo ficam no fim da lista.
            let note = NoteEditing.makeNote(in: modelContext)
            note.sortOrder = (roots.map(\.sortOrder).max() ?? -1) + 1
            openedNote = note
        } else {
            openedNote = NoteEditing.makeNote(parent: parent, in: modelContext)
        }
        try? modelContext.save()
    }

    /// Pede confirmação só quando a página tem subpáginas.
    private func requestDelete(_ note: Note) {
        if note.children?.isEmpty ?? true {
            delete(note)
        } else {
            noteToDelete = note
        }
    }

    private func delete(_ note: Note) {
        withAnimation {
            modelContext.delete(note)
            try? modelContext.save()
        }
    }
}

/// Pesquisa no título e no texto dos blocos.
enum NoteSearch {
    static func filter(_ notes: [Note], matching query: String) -> [Note] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return notes }
        return notes.filter { note in
            note.title.localizedStandardContains(query) || note.plainText.localizedStandardContains(query)
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        NotesView()
    }
}
