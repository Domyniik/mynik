import PhotosUI
import SwiftData
import SwiftUI

/// Editor de uma página: título, blocos e subpáginas.
struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note

    @FocusState private var focusedBlock: String?
    @State private var newChild: Note?
    @State private var photoItem: PhotosPickerItem?
    @State private var isImportingImage = false
    @State private var isShowingImageError = false

    static let icons = ["📄", "📝", "💡", "📚", "🗂️", "✅", "🎯", "💼", "🏠", "🚗", "✈️", "💰", "🛍️", "❤️", "🧠", "📅"]

    var body: some View {
        List {
            Section {
                if !note.ancestors.isEmpty {
                    Text(note.ancestors.map(\.displayTitle).joined(separator: " › "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Menu {
                        ForEach(Self.icons, id: \.self) { icon in
                            Button(icon) { note.icon = icon }
                        }
                    } label: {
                        Text(note.icon).font(.largeTitle)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                    .fixedSize()
                    .accessibilityLabel("Ícone da página")

                    TextField("Sem título", text: $note.title, axis: .vertical)
                        .font(.largeTitle.bold())
                }
            }
            .listRowSeparator(.hidden)

            Section {
                ForEach(note.sortedBlocks) { block in
                    NoteBlockView(block: block, focus: $focusedBlock) {
                        handleReturn(in: block)
                    }
                    .listRowSeparator(.hidden)
                    .contextMenu { blockMenu(block) }
                }
                .onMove { source, destination in
                    NoteEditing.moveBlocks(in: note, from: source, to: destination)
                }
                .onDelete { offsets in
                    let blocks = note.sortedBlocks
                    for index in offsets { NoteEditing.deleteBlock(blocks[index], from: note, context: modelContext) }
                }

                addBlockMenu
                    .listRowSeparator(.hidden)
            }

            Section("Subpáginas") {
                ForEach(note.sortedChildren) { child in
                    NavigationLink(value: child) {
                        Label { Text(child.displayTitle) } icon: { Text(child.icon) }
                    }
                }
                Button("Nova subpágina", systemImage: "plus") {
                    newChild = NoteEditing.makeNote(parent: note, in: modelContext)
                }
            }
        }
        .navigationTitle(note.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $newChild) { child in
            NoteEditorView(note: child)
        }
        .photosPicker(isPresented: $isImportingImage, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            guard let item = photoItem else { return }
            photoItem = nil
            Task { await insertImage(from: item) }
        }
        .onChange(of: note.title) { NoteEditing.touch(note) }
        .onAppear {
            if note.blocks?.isEmpty ?? true {
                NoteEditing.insertBlock(.text, in: note, context: modelContext)
            }
        }
        .onDisappear { try? modelContext.save() }
        .alert("Não foi possível abrir a imagem", isPresented: $isShowingImageError) { }
    }

    private var addBlockMenu: some View {
        Menu {
            ForEach(NoteBlockKind.allCases) { kind in
                Button(kind.title, systemImage: kind.symbolName) { addBlock(kind) }
            }
        } label: {
            Label("Adicionar bloco", systemImage: "plus")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func blockMenu(_ block: NoteBlock) -> some View {
        if block.kind.isTextual {
            Menu("Transformar em", systemImage: "arrow.triangle.2.circlepath") {
                ForEach(NoteBlockKind.allCases.filter { $0.isTextual && $0 != block.kind }) { kind in
                    Button(kind.title, systemImage: kind.symbolName) { NoteEditing.convert(block, to: kind) }
                }
            }
        }
        Button("Mover para cima", systemImage: "arrow.up") { NoteEditing.moveBlock(block, by: -1, in: note) }
        Button("Mover para baixo", systemImage: "arrow.down") { NoteEditing.moveBlock(block, by: 1, in: note) }
        Divider()
        Button("Apagar bloco", systemImage: "trash", role: .destructive) {
            withAnimation { NoteEditing.deleteBlock(block, from: note, context: modelContext) }
        }
    }

    private func addBlock(_ kind: NoteBlockKind) {
        if kind == .image {
            isImportingImage = true
            return
        }
        let block = NoteEditing.insertBlock(kind, in: note, context: modelContext)
        focusedBlock = block.uid
    }

    /// Return num título cria um parágrafo; num item de checklist cria outro item
    /// (ou, se estiver vazio, volta a ser texto, como no Notion).
    private func handleReturn(in block: NoteBlock) {
        if block.kind == .checklist, block.text.trimmingCharacters(in: .whitespaces).isEmpty {
            NoteEditing.convert(block, to: .text)
            focusedBlock = block.uid
            return
        }
        let next: NoteBlockKind = block.kind == .checklist ? .checklist : .text
        let created = NoteEditing.insertBlock(next, after: block, in: note, context: modelContext)
        focusedBlock = created.uid
    }

    private func insertImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            isShowingImageError = true
            return
        }
        let jpeg = await Task.detached { ImageDownsampler.jpegData(from: data) }.value
        guard let jpeg else {
            isShowingImageError = true
            return
        }
        let focused = note.sortedBlocks.first { $0.uid == focusedBlock }
        NoteEditing.insertBlock(.image, imageData: jpeg, after: focused, in: note, context: modelContext)
        try? modelContext.save()
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(filter: #Predicate<Note> { $0.parent == nil }) var notes: [Note]
    NavigationStack {
        if let note = notes.first {
            NoteEditorView(note: note)
        }
    }
}
