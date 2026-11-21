import SwiftUI

/// Destaque: emoji e texto numa caixa colorida.
struct NoteCalloutBlockView<Field: View>: View {
    @Bindable var block: NoteBlock
    @ViewBuilder let field: () -> Field

    static var emojis: [String] { ["💡", "⚠️", "📌", "✅", "❗️", "🔥", "💰", "📣", "🧠", "ℹ️"] }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Menu {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button(emoji) { block.emoji = emoji }
                }
            } label: {
                Text(block.emoji).font(.title3)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .accessibilityLabel("Emoji do destaque")
            field()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: .rect(cornerRadius: 10))
    }
}

/// Alternar: título com seta; o conteúdo só aparece quando está aberto.
struct NoteToggleBlockView<Field: View>: View {
    @Bindable var block: NoteBlock
    @ViewBuilder let field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Button {
                    withAnimation(.snappy) { block.isExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(block.isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(block.isExpanded ? "Fechar" : "Abrir")
                field().fontWeight(.medium)
            }
            if block.isExpanded {
                TextField("Conteúdo escondido…", text: $block.detail, axis: .vertical)
                    .padding(.leading, 22)
                    .textFieldStyle(.plain)
            }
        }
    }
}

/// Código: texto monoespaçado, linguagem e botão de copiar.
struct NoteCodeBlockView<Field: View>: View {
    @Bindable var block: NoteBlock
    @ViewBuilder let field: () -> Field

    static var languages: [String] { ["", "swift", "python", "javascript", "typescript", "json", "sql", "bash", "html", "css", "markdown"] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Menu(block.language.isEmpty ? "Texto simples" : block.language) {
                    ForEach(Self.languages, id: \.self) { language in
                        Button(language.isEmpty ? "Texto simples" : language) { block.language = language }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .font(.caption)
                .fixedSize()
                Spacer()
                Button("Copiar", systemImage: "doc.on.doc") { Clipboard.copy(block.text) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            field()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: 10))
    }
}

/// Tabela simples: grelha de células editáveis com cabeçalho.
struct NoteTableBlockView: View {
    @Bindable var block: NoteBlock

    private var table: NoteTable { NoteTable(text: block.text) }

    var body: some View {
        let table = table
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(table.rows.indices, id: \.self) { row in
                        GridRow {
                            ForEach(0..<table.columnCount, id: \.self) { column in
                                TextField("", text: cell(row, column))
                                    .textFieldStyle(.plain)
                                    .fontWeight(row == 0 ? .semibold : .regular)
                                    .padding(6)
                                    .frame(minWidth: 110, alignment: .leading)
                                    .background(row == 0 ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear))
                                    .border(.separator, width: 0.5)
                            }
                        }
                        .contextMenu {
                            Button("Apagar linha", systemImage: "trash", role: .destructive) {
                                update { $0.removeRow(at: row) }
                            }
                        }
                    }
                }
            }
            HStack {
                Button("Linha", systemImage: "plus") { update { $0.addRow() } }
                Button("Coluna", systemImage: "plus") { update { $0.addColumn() } }
                if table.columnCount > 1 {
                    Button("Coluna", systemImage: "minus") { update { $0.removeColumn(at: $0.columnCount - 1) } }
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private func cell(_ row: Int, _ column: Int) -> Binding<String> {
        Binding {
            let rows = table.rows
            return rows.indices.contains(row) && rows[row].indices.contains(column) ? rows[row][column] : ""
        } set: { value in
            update { table in
                guard table.rows.indices.contains(row), table.rows[row].indices.contains(column) else { return }
                table.rows[row][column] = value
            }
        }
    }

    private func update(_ change: (inout NoteTable) -> Void) {
        var table = table
        change(&table)
        block.text = table.text
        if let note = block.note { NoteEditing.touch(note) }
    }
}
