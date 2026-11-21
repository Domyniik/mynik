import Foundation
import SwiftData

/// Operações de edição de uma nota: criar páginas e inserir, mover ou apagar blocos.
enum NoteEditing {
    /// Cria uma página (na raiz ou como subpágina) já com um bloco de texto vazio.
    @discardableResult
    static func makeNote(title: String = "", parent: Note? = nil, in context: ModelContext) -> Note {
        let note = Note(title: title)
        note.sortOrder = (parent?.children?.map(\.sortOrder).max() ?? -1) + 1
        context.insert(note)
        // Só depois de inserir, para o SwiftData atualizar também `parent.children`.
        note.parent = parent
        let block = NoteBlock(kind: .text)
        context.insert(block)
        block.note = note
        return note
    }

    /// Insere um bloco depois de `previous` (ou no fim) e renumera a ordem.
    @discardableResult
    static func insertBlock(
        _ kind: NoteBlockKind,
        text: String = "",
        imageData: Data? = nil,
        after previous: NoteBlock? = nil,
        in note: Note,
        context: ModelContext
    ) -> NoteBlock {
        var blocks = note.sortedBlocks
        let block = NoteBlock(kind: kind, text: text, imageData: imageData)
        context.insert(block)
        block.note = note
        if let previous, let index = blocks.firstIndex(where: { $0 === previous }) {
            blocks.insert(block, at: index + 1)
        } else {
            blocks.append(block)
        }
        renumber(blocks)
        touch(note)
        return block
    }

    /// Move blocos (para `onMove` de uma lista).
    static func moveBlocks(in note: Note, from source: IndexSet, to destination: Int) {
        var blocks = note.sortedBlocks
        blocks.move(fromOffsets: source, toOffset: destination)
        renumber(blocks)
        touch(note)
    }

    /// Sobe (`-1`) ou desce (`+1`) um bloco uma posição.
    static func moveBlock(_ block: NoteBlock, by offset: Int, in note: Note) {
        var blocks = note.sortedBlocks
        guard let index = blocks.firstIndex(where: { $0 === block }) else { return }
        let target = index + offset
        guard blocks.indices.contains(target) else { return }
        blocks.swapAt(index, target)
        renumber(blocks)
        touch(note)
    }

    /// Cópia de um bloco logo a seguir ao original.
    @discardableResult
    static func duplicateBlock(_ block: NoteBlock, in note: Note, context: ModelContext) -> NoteBlock {
        let copy = insertBlock(block.kind, text: block.text, imageData: block.imageData, after: block, in: note, context: context)
        copy.isChecked = block.isChecked
        copy.emoji = block.emoji
        copy.language = block.language
        copy.detail = block.detail
        copy.isExpanded = block.isExpanded
        return copy
    }

    static func deleteBlock(_ block: NoteBlock, from note: Note, context: ModelContext) {
        let remaining = note.sortedBlocks.filter { $0 !== block }
        // Tira já da relação: o `delete` só a atualiza ao guardar.
        note.blocks?.removeAll { $0 === block }
        context.delete(block)
        renumber(remaining)
        touch(note)
    }

    /// Converte um bloco de texto noutro tipo de texto (ex.: parágrafo → título).
    static func convert(_ block: NoteBlock, to kind: NoteBlockKind) {
        guard block.kind.isTextual, kind.isTextual else { return }
        block.kind = kind
        if kind != .checklist { block.isChecked = false }
        if let note = block.note { touch(note) }
    }

    /// Aplica uma escolha do menu "/" ao bloco onde se escreveu "/…".
    ///
    /// Tipos de texto transformam o bloco; divisor e tabela também, e o divisor
    /// ganha logo um parágrafo a seguir. Devolve o bloco que deve ficar com o foco
    /// (`nil` na imagem, que é escolhida à parte).
    @discardableResult
    static func applySlashCommand(_ kind: NoteBlockKind, to block: NoteBlock, in note: Note, context: ModelContext) -> NoteBlock? {
        block.text = ""
        block.isChecked = false
        switch kind {
        case .image:
            return nil
        case .divider:
            block.kind = .divider
            touch(note)
            return insertBlock(.text, after: block, in: note, context: context)
        case .table:
            block.kind = .table
            block.text = NoteTable(text: "").text
            touch(note)
            return block
        default:
            block.kind = kind
            touch(note)
            return block
        }
    }

    /// Acrescenta blocos lidos de Markdown no fim da página.
    static func append(_ parsed: [NoteMarkdown.ParsedBlock], to note: Note, context: ModelContext) {
        var blocks = note.sortedBlocks
        for item in parsed {
            let block = NoteBlock(kind: item.kind, text: item.text, isChecked: item.isChecked)
            if !item.language.isEmpty { block.language = item.language }
            if !item.emoji.isEmpty { block.emoji = item.emoji }
            context.insert(block)
            block.note = note
            blocks.append(block)
        }
        renumber(blocks)
        touch(note)
    }

    /// Número de cada item de lista numerada (conta a partir de 1 em cada lista seguida).
    static func listNumbers(for blocks: [NoteBlock]) -> [String: Int] {
        var numbers: [String: Int] = [:]
        var current = 0
        for block in blocks {
            current = block.kind == .numbered ? current + 1 : 0
            if current > 0 { numbers[block.uid] = current }
        }
        return numbers
    }

    static func touch(_ note: Note, now: Date = .now) {
        note.updatedAt = now
    }

    private static func renumber(_ blocks: [NoteBlock]) {
        for (index, block) in blocks.enumerated() where block.sortOrder != index {
            block.sortOrder = index
        }
    }
}
