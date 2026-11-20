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
                if let note = block.note { NoteEditing.touch(note) }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .text:
            TextField("Escreve algo…", text: $block.text, axis: .vertical)
                .focused(focus, equals: block.uid)
        case .heading:
            TextField("Título", text: $block.text)
                .font(.title2.bold())
                .focused(focus, equals: block.uid)
                .onSubmit(onReturn)
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

                TextField("Item", text: $block.text)
                    .strikethrough(block.isChecked)
                    .foregroundStyle(block.isChecked ? .secondary : .primary)
                    .focused(focus, equals: block.uid)
                    .onSubmit(onReturn)
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
