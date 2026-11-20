import SwiftUI

/// Um bloco editável de uma nota.
struct NoteBlockView: View {
    @Bindable var block: NoteBlock
    var focus: FocusState<String?>.Binding
    /// Return num título ou item de checklist (cria o bloco seguinte).
    let onReturn: () -> Void

    var body: some View {
        content
            .onChange(of: block.text) {
                applyShortcut()
                if let note = block.note { NoteEditing.touch(note) }
            }
    }

    /// `# `, `- [ ] ` ou `[] ` no início de um parágrafo mudam o tipo do bloco.
    private func applyShortcut() {
        guard block.kind == .text, let shortcut = NoteMarkdown.shortcut(for: block.text) else { return }
        block.kind = shortcut.kind
        block.isChecked = shortcut.isChecked
        block.text = shortcut.text
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .text:
            MarkdownTextField(placeholder: "Escreve algo… (Markdown, [[ligações]])", text: $block.text, axis: .vertical, focus: focus, id: block.uid)
        case .heading:
            MarkdownTextField(placeholder: "Título", text: $block.text, focus: focus, id: block.uid, onSubmit: onReturn)
                .font(.title2.bold())
        case .checklist:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    withAnimation { block.isChecked.toggle() }
                } label: {
                    Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                        .foregroundStyle(block.isChecked ? Color.accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(block.isChecked ? "Desmarcar" : "Marcar")

                MarkdownTextField(placeholder: "Item", text: $block.text, focus: focus, id: block.uid, onSubmit: onReturn)
                    .strikethrough(block.isChecked)
                    .foregroundStyle(block.isChecked ? .secondary : .primary)
            }
        case .image:
            VStack(alignment: .leading, spacing: 6) {
                NoteImageView(data: block.imageData)
                TextField("Legenda", text: $block.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .focused(focus, equals: block.uid)
            }
        }
    }
}

/// Imagem de um bloco, descodificada uma vez.
struct NoteImageView: View {
    let data: Data?
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(.rect(cornerRadius: 10))
            } else {
                Label("Imagem indisponível", systemImage: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(.fill.quaternary, in: .rect(cornerRadius: 10))
            }
        }
        .task(id: data) {
            image = data.flatMap { ImageDownsampler.cgImage(from: $0, maxPixelSize: 1400) }
        }
    }
}
