import SwiftUI

/// Menu "Bloco" da barra do editor, com os atalhos de teclado (iPad
/// com teclado): mover, duplicar, apagar e transformar o bloco com o foco.
struct NoteBlockCommands: View {
    /// Bloco com o foco (`nil` desativa o menu).
    let block: NoteBlock?
    let onMove: (Int) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onConvert: (NoteBlockKind) -> Void

    /// Atalhos ⌥⌘0…8 para transformar, pela mesma ordem.
    static let convertible: [NoteBlockKind] = [
        .text, .heading, .heading2, .heading3, .checklist, .bulleted, .numbered, .toggle, .code,
    ]

    var body: some View {
        Menu("Bloco", systemImage: "square.stack") {
            Button("Mover para cima", systemImage: "arrow.up") { onMove(-1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            Button("Mover para baixo", systemImage: "arrow.down") { onMove(1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            Button("Duplicar", systemImage: "plus.square.on.square") { onDuplicate() }
                .keyboardShortcut("d", modifiers: .command)
            Divider()
            Section("Transformar em") {
                ForEach(Array(Self.convertible.enumerated()), id: \.element) { index, kind in
                    Button(kind.title, systemImage: kind.symbolName) { onConvert(kind) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index))), modifiers: [.command, .option])
                        .disabled(!(block?.kind.isTextual ?? false) || block?.kind == kind)
                }
            }
            Divider()
            Button("Apagar bloco", systemImage: "trash", role: .destructive) { onDelete() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }
        .disabled(block == nil)
        .help("Ações do bloco com o foco")
    }
}
