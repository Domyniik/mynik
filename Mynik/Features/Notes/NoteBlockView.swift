import SwiftUI

/// Um bloco editável de uma nota.
struct NoteBlockView: View {
    @Bindable var block: NoteBlock
    var focus: FocusState<String?>.Binding
    /// Return num bloco de texto (cria o bloco seguinte, como no Notion).
    let onReturn: () -> Void

    var body: some View {
        content
            .onChange(of: block.text) {
                handleTextChange()
                if let note = block.note { NoteEditing.touch(note) }
            }
    }

    /// Atalhos de Markdown e Return.
    ///
    /// Texto, título e checklist usam sempre o mesmo campo, para o foco não se
    /// perder quando o bloco muda de tipo. Uma quebra de linha colada num título
    /// ou item também conta como Return.
    private func handleTextChange() {
        switch block.kind {
        case .text:
            // `# `, `- [ ] ` ou `[] ` no início de um parágrafo mudam o tipo do bloco.
            if let shortcut = NoteMarkdown.shortcut(for: block.text) {
                block.kind = shortcut.kind
                block.isChecked = shortcut.isChecked
                block.text = shortcut.text
            }
        case .heading, .checklist:
            if block.text.contains("\n") {
                block.text = block.text.replacingOccurrences(of: "\n", with: "")
                onReturn()
            }
        case .image:
            break
        }
    }

    private var placeholder: String {
        switch block.kind {
        case .heading: "Título"
        case .checklist: "Item"
        default: "Escreve algo… (Markdown, [[ligações]])"
        }
    }

    @ViewBuilder
    private var content: some View {
        if block.kind == .image {
            VStack(alignment: .leading, spacing: 6) {
                NoteImageView(data: block.imageData)
                TextField("Legenda", text: $block.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .focused(focus, equals: block.uid)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if block.kind == .checklist {
                    Button {
                        withAnimation { block.isChecked.toggle() }
                    } label: {
                        Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(block.isChecked ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(block.isChecked ? "Desmarcar" : "Marcar")
                }

                let isDone = block.kind == .checklist && block.isChecked
                MarkdownTextField(placeholder: placeholder, text: $block.text, axis: .vertical, focus: focus, id: block.uid, onSubmit: onReturn)
                    .font(block.kind == .heading ? .title2.bold() : .body)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
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
