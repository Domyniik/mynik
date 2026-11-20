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

    static func touch(_ note: Note, now: Date = .now) {
        note.updatedAt = now
    }

    private static func renumber(_ blocks: [NoteBlock]) {
        for (index, block) in blocks.enumerated() where block.sortOrder != index {
            block.sortOrder = index
        }
    }
}
