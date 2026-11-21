import SwiftUI

/// Um bloco editável de uma nota.
struct NoteBlockView: View {
    @Bindable var block: NoteBlock
    var focus: FocusState<String?>.Binding
    /// Número do item numa lista numerada.
    var listNumber: Int = 1
    /// Return no fim do bloco (cria o bloco seguinte).
    let onReturn: () -> Void
    /// Escolha no menu "/".
    let onSlashCommand: (NoteBlockKind) -> Void
    /// Apagar (⌫) num bloco vazio.
    var onDeleteEmpty: () -> Void = {}

    @State private var slashSelection = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if let query = slashQuery {
                SlashCommandMenu(kinds: NoteBlockKind.matching(query), selection: slashSelection) { kind in
                    onSlashCommand(kind)
                }
            }
        }
        .onChange(of: block.text) {
            handleTextChange()
            if let note = block.note { NoteEditing.touch(note) }
        }
        .onChange(of: slashQuery) { slashSelection = 0 }
    }

    // MARK: Menu "/"

    /// Texto depois de "/" quando o bloco é um parágrafo a começar por "/".
    private var slashQuery: String? {
        guard block.kind == .text, focus.wrappedValue == block.uid, block.text.hasPrefix("/") else { return nil }
        let query = String(block.text.dropFirst())
        guard !query.contains("\n"), query.count <= 20 else { return nil }
        return query
    }

    private var slashMatches: [NoteBlockKind] {
        slashQuery.map(NoteBlockKind.matching) ?? []
    }

    private func chooseSlashSelection() {
        let matches = slashMatches
        guard !matches.isEmpty else { return }
        onSlashCommand(matches[min(slashSelection, matches.count - 1)])
    }

    private func submit() {
        if slashQuery != nil {
            chooseSlashSelection()
        } else {
            onReturn()
        }
    }

    // MARK: Atalhos de Markdown e Return

    /// Texto, títulos, listas e citações usam sempre o mesmo campo, para o foco
    /// não se perder quando o bloco muda de tipo. Uma quebra de linha num bloco
    /// de uma só linha conta como Return.
    private func handleTextChange() {
        let kind = block.kind
        if kind == .text, block.text.hasPrefix("/"), block.text.contains("\n") {
            block.text = block.text.replacingOccurrences(of: "\n", with: "")
            chooseSlashSelection()
            return
        }
        if kind == .text, let shortcut = NoteMarkdown.shortcut(for: block.text) {
            block.kind = shortcut.kind
            block.isChecked = shortcut.isChecked
            block.text = shortcut.text
            if shortcut.kind == .code { block.language = shortcut.language }
            if shortcut.kind == .divider { onReturn() }
            return
        }
        if kind.isSingleLine, block.text.contains("\n") {
            block.text = block.text.replacingOccurrences(of: "\n", with: "")
            onReturn()
        }
    }

    // MARK: Conteúdo

    private var placeholder: String {
        switch block.kind {
        case .heading: "Título 1"
        case .heading2: "Título 2"
        case .heading3: "Título 3"
        case .checklist, .bulleted, .numbered: "Item"
        case .toggle: "Alternar"
        case .quote: "Citação"
        case .callout: "Escreve algo…"
        case .code: "Código"
        default: "Escreve algo, ou \"/\" para blocos… ([[ligações]], @menções)"
        }
    }

    private var font: Font {
        switch block.kind {
        case .heading: .title.bold()
        case .heading2: .title2.bold()
        case .heading3: .title3.bold()
        case .code: .body.monospaced()
        default: .body
        }
    }

    private var textField: some View {
        let isDone = block.kind == .checklist && block.isChecked
        return MarkdownTextField(
            placeholder: placeholder, text: $block.text, axis: .vertical,
            focus: focus, id: block.uid, rendersMarkdown: block.kind != .code, onSubmit: submit
        )
        .font(font)
        .strikethrough(isDone)
        .foregroundStyle(isDone ? .secondary : .primary)
        .onKeyPress(.downArrow) { moveSlashSelection(by: 1) }
        .onKeyPress(.upArrow) { moveSlashSelection(by: -1) }
        .onKeyPress(.escape) {
            guard slashQuery != nil else { return .ignored }
            block.text = ""
            return .handled
        }
        .onKeyPress(.delete) {
            guard block.text.isEmpty else { return .ignored }
            onDeleteEmpty()
            return .handled
        }
    }

    private func moveSlashSelection(by offset: Int) -> KeyPress.Result {
        let count = slashMatches.count
        guard count > 0 else { return .ignored }
        slashSelection = (slashSelection + offset + count) % count
        return .handled
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .image:
            VStack(alignment: .leading, spacing: 6) {
                NoteImageView(data: block.imageData)
                TextField("Legenda", text: $block.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .focused(focus, equals: block.uid)
            }
        case .divider:
            Divider()
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .accessibilityLabel("Divisor")
        case .table:
            NoteTableBlockView(block: block)
        case .code:
            NoteCodeBlockView(block: block) { textField }
        case .callout:
            NoteCalloutBlockView(block: block) { textField }
        case .toggle:
            NoteToggleBlockView(block: block) { textField }
        case .quote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.primary)
                    .frame(width: 3)
                textField.italic()
            }
            .fixedSize(horizontal: false, vertical: true)
        default:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                marker
                textField
            }
            .padding(.top, block.kind.isHeading ? 6 : 0)
        }
    }

    @ViewBuilder
    private var marker: some View {
        switch block.kind {
        case .checklist:
            Button {
                withAnimation { block.isChecked.toggle() }
            } label: {
                Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(block.isChecked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(block.isChecked ? "Desmarcar" : "Marcar")
        case .bulleted:
            Text("•").fontWeight(.bold).accessibilityHidden(true)
        case .numbered:
            Text("\(listNumber).").monospacedDigit().accessibilityHidden(true)
        default:
            EmptyView()
        }
    }
}

/// Lista de tipos de bloco que aparece ao escrever "/" num parágrafo vazio.
struct SlashCommandMenu: View {
    let kinds: [NoteBlockKind]
    let selection: Int
    let onChoose: (NoteBlockKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if kinds.isEmpty {
                Text("Sem resultados")
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            ForEach(Array(kinds.prefix(8).enumerated()), id: \.element) { index, kind in
                Button { onChoose(kind) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: kind.symbolName)
                            .frame(width: 28, height: 28)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.title)
                            Text(kind.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(index == selection ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.clear),
                                in: .rect(cornerRadius: 8))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: 320, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .accessibilityLabel("Blocos")
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
