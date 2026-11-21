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
    @State private var openedDay: String?

    var body: some View {
        List {
            Section {
                NoteHeaderView(note: note, focus: $focusedBlock) { openedNote = $0 }
                if let database = note.database {
                    NoteRowPropertiesView(row: note, database: database)
                }
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

            if note.isDatabase {
                NoteDatabaseView(database: note) { openedNote = $0 }
            } else {
                subpagesSection
            }

            NoteLinksSection(
                note: note,
                onOpenNote: { openedNote = $0 },
                onOpenProject: { openedProject = $0 },
                onOpenTransaction: { editingTransaction = $0 }
            )
        }
        .safeAreaInset(edge: .bottom) { slashMenu }
        .environment(\.openURL, OpenURLAction { url in
            guard let target = NoteMention.target(from: url) else { return .systemAction }
            open(target)
            return .handled
        })
        .sheet(item: Binding(get: { openedDay.map(DayID.init) }, set: { openedDay = $0?.id })) { day in
            DateMentionsView(day: day.id) { openedNote = $0 }
        }
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
            ToolbarItem(placement: .secondaryAction) {
                if note.isTemplate {
                    Button("Nova página a partir deste template", systemImage: "doc.on.doc") {
                        openedNote = NoteTemplates.instantiate(template: note, in: modelContext)
                    }
                } else {
                    Button("Guardar como template", systemImage: "square.on.square.dashed") {
                        NoteTemplates.saveAsTemplate(note, in: modelContext)
                        try? modelContext.save()
                    }
                }
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

    private var subpagesSection: some View {
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
            Button("Nova base de dados", systemImage: "tablecells.badge.ellipsis") {
                openedNote = NoteDatabase.makeDatabase(title: "Base de dados", parent: note, in: modelContext)
            }
        }
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

    /// Menu "/" ou sugestões "@", por baixo do editor (fora da lista, para o
    /// bloco não perder o foco).
    @ViewBuilder
    private var slashMenu: some View {
        if let block = focusedBlockModel, let query = slashQuery {
            SlashCommandMenu(kinds: NoteBlockKind.matching(query), selection: slashSelection) { kind in
                applySlashCommand(kind, to: block)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
        } else if let block = focusedBlockModel, block.kind.isTextual, block.kind != .code,
                  let query = NoteMention.activeQuery(in: block.text) {
            MentionPicker(query: query, current: note) { label, target in
                insertMention(label: label, target: target, in: block)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    /// Escreve a menção no bloco e liga o item à página (aparece nas ligações
    /// dos dois lados).
    private func insertMention(label: String, target: NoteMention.Target, in block: NoteBlock) {
        block.text = NoteMention.replacingActiveQuery(in: block.text, with: NoteMention.token(label: label, target: target))
        switch target {
        case .note(let uid):
            if let other = fetch(Note.self, uid: uid), !NoteLinks.isLinked(other, to: note) { NoteLinks.toggle(other, in: note) }
        case .project(let uid):
            if let project = fetch(Project.self, uid: uid), !NoteLinks.isLinked(project, to: note) { NoteLinks.toggle(project, in: note) }
        case .transaction(let uid):
            if let transaction = fetch(FinanceTransaction.self, uid: uid), !NoteLinks.isLinked(transaction, to: note) {
                NoteLinks.toggle(transaction, in: note)
            }
        case .date, .title:
            break
        }
        focus(block)
    }

    /// Abre o destino de uma menção tocada.
    private func open(_ target: NoteMention.Target) {
        switch target {
        case .note(let uid): openedNote = fetch(Note.self, uid: uid)
        case .project(let uid): openedProject = fetch(Project.self, uid: uid)
        case .transaction(let uid): editingTransaction = fetch(FinanceTransaction.self, uid: uid)
        case .date(let day): openedDay = day
        case .title(let title):
            let notes = (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
            if let match = notes.first(where: { $0.title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(title) == .orderedSame }) {
                openedNote = match
            } else {
                let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
                openedProject = projects.first { $0.name.caseInsensitiveCompare(title) == .orderedSame }
            }
        }
    }

    private func fetch(_: Note.Type, uid: String) -> Note? {
        try? modelContext.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.uid == uid })).first
    }

    private func fetch(_: Project.Type, uid: String) -> Project? {
        try? modelContext.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.uid == uid })).first
    }

    private func fetch(_: FinanceTransaction.Type, uid: String) -> FinanceTransaction? {
        try? modelContext.fetch(FetchDescriptor<FinanceTransaction>(predicate: #Predicate { $0.uid == uid })).first
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

/// Dia aberto a partir de uma menção de data (para `.sheet(item:)`).
private struct DayID: Identifiable {
    let id: String
}
