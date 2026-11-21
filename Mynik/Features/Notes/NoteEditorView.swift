import PhotosUI
import SwiftData
import SwiftUI

/// Editor de uma página: título, blocos e subpáginas.
struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note

    @FocusState private var focusedBlock: String?
    @State private var openedNote: Note?
    @State private var openedProject: Project?
    @State private var editingTransaction: FinanceTransaction?
    @State private var photoItem: PhotosPickerItem?
    @State private var isImportingImage = false
    @State private var isShowingImageError = false
    @State private var slashSelection = 0

    var body: some View {
        List {
            Section {
                NoteHeaderView(note: note, focus: $focusedBlock) { openedNote = $0 }
            }
            .listRowSeparator(.hidden)

            Section {
                let blocks = note.sortedBlocks
                let numbers = NoteEditing.listNumbers(for: blocks)
                ForEach(blocks) { block in
                    NoteBlockView(
                        block: block,
                        focus: $focusedBlock,
                        listNumber: numbers[block.uid] ?? 1,
                        onReturn: { handleReturn(in: block) },
                        onSlashCommand: { applySlashCommand($0, to: block) },
                        onDeleteEmpty: { deleteEmpty(block) },
                        slashSelection: $slashSelection
                    )
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

                HStack {
                    addBlockMenu
                    Spacer()
                    PasteButton(payloadType: String.self) { strings in
                        importMarkdown(strings.joined(separator: "\n\n"))
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                    .help("Colar Markdown como blocos")
                }
                .listRowSeparator(.hidden)
            }

            Section("Subpáginas") {
                ForEach(note.sortedChildren) { child in
                    Button { openedNote = child } label: {
                        Label { Text(child.displayTitle) } icon: { Text(child.icon) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                Button("Nova subpágina", systemImage: "plus") {
                    openedNote = NoteEditing.makeNote(parent: note, in: modelContext)
                }
            }

            NoteLinksSection(
                note: note,
                onOpenNote: { openedNote = $0 },
                onOpenProject: { openedProject = $0 },
                onOpenTransaction: { editingTransaction = $0 }
            )
        }
        .safeAreaInset(edge: .bottom) { slashMenu }
        .onChange(of: slashQuery) { slashSelection = 0 }
        .navigationTitle(note.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    // Sai da edição: o texto passa a aparecer formatado.
                    Button("Concluído") { focusedBlock = nil }
                        .fontWeight(.semibold)
                }
            }
            #endif
            ToolbarItem(placement: .secondaryAction) {
                NoteBlockCommands(
                    block: focusedBlockModel,
                    onMove: { offset in focusedBlockModel.map { moveKeepingFocus($0, by: offset) } },
                    onDuplicate: {
                        guard let block = focusedBlockModel else { return }
                        focus(NoteEditing.duplicateBlock(block, in: note, context: modelContext))
                    },
                    onDelete: {
                        guard let block = focusedBlockModel else { return }
                        withAnimation { NoteEditing.deleteBlock(block, from: note, context: modelContext) }
                    },
                    onConvert: { kind in focusedBlockModel.map { NoteEditing.convert($0, to: kind) } }
                )
            }
            ToolbarItem(placement: .primaryAction) {
                Button(
                    note.isFavorite ? "Tirar dos favoritos" : "Adicionar aos favoritos",
                    systemImage: note.isFavorite ? "star.fill" : "star"
                ) {
                    note.isFavorite.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: NoteMarkdown.export(title: note.displayTitle, blocks: note.sortedBlocks),
                    subject: Text(note.displayTitle),
                    preview: SharePreview(note.displayTitle)
                ) {
                    Label("Exportar Markdown", systemImage: "square.and.arrow.up")
                }
            }
        }
        // Destinos locais: o editor também abre dentro de Projetos.
        .navigationDestination(item: $openedNote) { other in
            NoteEditorView(note: other)
        }
        .navigationDestination(item: $openedProject) { project in
            ProjectDetailView(project: project)
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionFormView(transaction: transaction)
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
        Button("Mover para cima", systemImage: "arrow.up") { moveKeepingFocus(block, by: -1) }
        Button("Mover para baixo", systemImage: "arrow.down") { moveKeepingFocus(block, by: 1) }
        Button("Duplicar", systemImage: "plus.square.on.square") {
            NoteEditing.duplicateBlock(block, in: note, context: modelContext)
        }
        Divider()
        Button("Apagar bloco", systemImage: "trash", role: .destructive) {
            withAnimation { NoteEditing.deleteBlock(block, from: note, context: modelContext) }
        }
    }

    /// Pesquisa do menu "/" no bloco com o foco.
    private var slashQuery: String? {
        focusedBlockModel.flatMap(NoteBlockView.slashQuery(for:))
    }

    @ViewBuilder
    private var slashMenu: some View {
        if let block = focusedBlockModel, let query = slashQuery {
            SlashCommandMenu(kinds: NoteBlockKind.matching(query), selection: slashSelection) { kind in
                applySlashCommand(kind, to: block)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var focusedBlockModel: NoteBlock? {
        guard let focusedBlock else { return nil }
        return note.sortedBlocks.first { $0.uid == focusedBlock }
    }

    /// Move um bloco e devolve-lhe o foco (a lista recria a linha ao mudar a ordem).
    private func moveKeepingFocus(_ block: NoteBlock, by offset: Int) {
        let hadFocus = focusedBlock == block.uid
        withAnimation(.snappy) { NoteEditing.moveBlock(block, by: offset, in: note) }
        if hadFocus { focus(block) }
    }

    private func addBlock(_ kind: NoteBlockKind) {
        if kind == .image {
            isImportingImage = true
            return
        }
        let block = NoteEditing.insertBlock(kind, in: note, context: modelContext)
        if kind == .table { block.text = NoteTable(text: "").text }
        if kind == .divider {
            focus(NoteEditing.insertBlock(.text, after: block, in: note, context: modelContext))
        } else {
            focus(block)
        }
    }

    /// Return cria o bloco seguinte: outro item numa checklist (ou, se o item
    /// estiver vazio, volta a ser texto, como no Notion) e um parágrafo nos outros.
    private func handleReturn(in block: NoteBlock) {
        if block.kind.continuesOnReturn, block.text.trimmingCharacters(in: .whitespaces).isEmpty {
            NoteEditing.convert(block, to: .text)
            focusedBlock = block.uid
            return
        }
        let next: NoteBlockKind = block.kind.continuesOnReturn ? block.kind : .text
        let created = NoteEditing.insertBlock(next, after: block, in: note, context: modelContext)
        focus(created)
    }

    private func applySlashCommand(_ kind: NoteBlockKind, to block: NoteBlock) {
        if kind == .image {
            block.text = ""
            isImportingImage = true
            return
        }
        if let target = NoteEditing.applySlashCommand(kind, to: block, in: note, context: modelContext) {
            focus(target)
        }
    }

    /// ⌫ num bloco vazio: apaga-o e passa o foco ao bloco de cima.
    private func deleteEmpty(_ block: NoteBlock) {
        let blocks = note.sortedBlocks
        guard blocks.count > 1, let index = blocks.firstIndex(where: { $0 === block }) else { return }
        if block.kind != .text {
            NoteEditing.convert(block, to: .text)
            return
        }
        let previous = index > 0 ? blocks[index - 1] : nil
        NoteEditing.deleteBlock(block, from: note, context: modelContext)
        if let previous { focusedBlock = previous.uid }
    }

    /// Dá o foco a um bloco acabado de criar, depois de ele aparecer na lista
    /// (antes disso o foco falharia e o teclado fechava).
    private func focus(_ block: NoteBlock) {
        let id = block.uid
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            focusedBlock = id
        }
    }

    /// Acrescenta blocos lidos de Markdown no fim da página (substitui um único bloco vazio).
    private func importMarkdown(_ markdown: String) {
        let parsed = NoteMarkdown.parse(markdown)
        guard !parsed.isEmpty else { return }
        let existing = note.sortedBlocks
        if existing.count == 1, let only = existing.first, only.kind == .text, only.text.isEmpty {
            NoteEditing.deleteBlock(only, from: note, context: modelContext)
        }
        NoteEditing.append(parsed.filter { $0.kind != .image }, to: note, context: modelContext)
        try? modelContext.save()
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
