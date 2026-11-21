import Foundation

/// Markdown nas notas: formatação inline, menções `[[Título]]`, atalhos ao
/// escrever e exportação/importação de páginas.
nonisolated enum NoteMarkdown {
    /// Bloco lido de um texto Markdown.
    struct ParsedBlock: Equatable {
        var kind: NoteBlockKind
        var text: String
        var isChecked = false
        /// Linguagem (código) ou emoji (destaque).
        var language = ""
        var emoji = ""
        /// Caminho da imagem tal como aparece no Markdown (`![legenda](caminho)`).
        var imagePath = ""
    }

    // MARK: Menções [[Título]]

    /// Títulos mencionados com `[[…]]`, sem repetidos, pela ordem em que aparecem.
    static func mentions(in text: String) -> [String] {
        var seen = Set<String>()
        return text.matches(of: mentionPattern).compactMap { match in
            let title = String(match.output.1).trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty, seen.insert(title.lowercased()).inserted else { return nil }
            return title
        }
    }

    /// Texto pronto a mostrar: Markdown inline e menções realçadas.
    static func attributed(_ text: String) -> AttributedString {
        let linked = text.replacing(mentionPattern) { match in
            let title = String(match.output.1)
            let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
            return "[\(title)](mynik://mention/\(encoded))"
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: linked, options: options)) ?? AttributedString(text)
    }

    nonisolated(unsafe) private static let mentionPattern = /\[\[([^\[\]\n]+)\]\]/

    // MARK: Atalhos ao escrever

    private static let shortcutRules: [(prefix: String, kind: NoteBlockKind, checked: Bool)] = [
        ("### ", .heading3, false), ("## ", .heading2, false), ("# ", .heading, false),
        ("- [ ] ", .checklist, false), ("- [x] ", .checklist, true), ("- [X] ", .checklist, true),
        ("[] ", .checklist, false), ("[ ] ", .checklist, false),
        ("- ", .bulleted, false), ("* ", .bulleted, false), ("• ", .bulleted, false),
        ("> ", .quote, false), ("```", .code, false),
    ]

    /// Converte o início de um parágrafo no tipo de bloco certo, como no Notion:
    /// `#`/`##`/`###` → títulos, `- ` → marcas, `1. ` → numerada, `[] ` → tarefa,
    /// `> ` → citação, ` ``` ` → código e `---` → divisor.
    static func shortcut(for text: String) -> ParsedBlock? {
        if text == "---" || text == "***" {
            return ParsedBlock(kind: .divider, text: "")
        }
        if let match = text.prefixMatch(of: /(\d{1,3})[.)][ ]/) {
            return ParsedBlock(kind: .numbered, text: String(text[match.range.upperBound...]))
        }
        for rule in shortcutRules where text.hasPrefix(rule.prefix) {
            var block = ParsedBlock(kind: rule.kind, text: String(text.dropFirst(rule.prefix.count)), isChecked: rule.checked)
            if rule.kind == .code {
                // ```swift → linguagem; o resto da linha fica vazio.
                block.language = block.text.trimmingCharacters(in: .whitespaces)
                block.text = ""
            }
            return block
        }
        return nil
    }

    // MARK: Exportar

    /// Página em Markdown (o mesmo formato que o export do Notion): título da
    /// página e títulos como `#`, listas, tarefas, citações, código, tabelas…
    static func export(title: String, blocks: [NoteBlock]) -> String {
        var lines: [String] = ["# \(title)"]
        var previous: NoteBlockKind?
        var number = 0
        for block in blocks {
            let kind = block.kind
            // Itens de lista seguidos ficam numa só lista.
            let isListRun = previous == kind && kind.continuesOnReturn
            if !isListRun { lines.append("") }
            number = kind == .numbered ? (isListRun ? number + 1 : 1) : 0
            switch kind {
            case .text: lines.append(block.text)
            case .heading: lines.append("# \(block.text)")
            case .heading2: lines.append("## \(block.text)")
            case .heading3: lines.append("### \(block.text)")
            case .bulleted: lines.append("- \(block.text)")
            case .numbered: lines.append("\(number). \(block.text)")
            case .checklist: lines.append("- [\(block.isChecked ? "x" : " ")] \(block.text)")
            case .toggle:
                lines.append("- \(block.text)")
                for line in block.detail.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append("    \(line)")
                }
            case .quote:
                lines.append(contentsOf: block.text.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" })
            case .callout:
                lines.append("<aside>")
                lines.append("\(block.emoji) \(block.text)")
                lines.append("</aside>")
            case .code:
                lines.append("```\(block.language)")
                lines.append(block.text)
                lines.append("```")
            case .table: lines.append(contentsOf: NoteTable(text: block.text).markdownLines)
            case .divider: lines.append("---")
            case .image: lines.append("![\(block.text)](imagem)")
            }
            previous = kind
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Importar

    /// Lê Markdown em blocos. Percebe títulos, listas, tarefas, citações,
    /// código entre ` ``` `, tabelas `| a | b |`, `<aside>` (destaques), divisores
    /// e imagens; linhas seguidas juntam-se num parágrafo.
    static func parse(_ markdown: String) -> [ParsedBlock] {
        var blocks: [ParsedBlock] = []
        var paragraph: [String] = []
        let lines = markdown.components(separatedBy: .newlines)
        var index = 0

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(ParsedBlock(kind: .text, text: paragraph.joined(separator: "\n")))
                paragraph = []
            }
        }

        while index < lines.count {
            let rawLine = lines[index]
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            index += 1

            if line.isEmpty {
                flushParagraph()
            } else if line.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                index += 1  // fecho
                blocks.append(ParsedBlock(kind: .code, text: code.joined(separator: "\n"),
                                          language: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
            } else if line.lowercased() == "<aside>" {
                flushParagraph()
                var body: [String] = []
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).lowercased() != "</aside>" {
                    body.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                index += 1
                var text = body.filter { !$0.isEmpty }.joined(separator: "\n")
                var emoji = "💡"
                if let first = text.first, first.isEmojiIcon {
                    emoji = String(first)
                    text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                blocks.append(ParsedBlock(kind: .callout, text: text, emoji: emoji))
            } else if line.hasPrefix("|") {
                flushParagraph()
                var rows = [line]
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(ParsedBlock(kind: .table, text: NoteTable(markdownRows: rows).text))
            } else if line.hasPrefix(">") {
                flushParagraph()
                var quote = [String(line.dropFirst()).trimmingCharacters(in: .whitespaces)]
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quote.append(String(lines[index].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(ParsedBlock(kind: .quote, text: quote.joined(separator: "\n")))
            } else if let image = line.wholeMatch(of: /!\[([^\]]*)\]\(([^)]*)\)/) {
                flushParagraph()
                blocks.append(ParsedBlock(kind: .image, text: String(image.output.1),
                                          imagePath: String(image.output.2).removingPercentEncoding ?? String(image.output.2)))
            } else if let block = shortcut(for: line) {
                flushParagraph()
                blocks.append(block)
            } else {
                paragraph.append(rawLine)
            }
        }
        flushParagraph()
        return blocks
    }
}

/// Tabela simples guardada no texto do bloco: células separadas por tabulação
/// e linhas por mudança de linha. A primeira linha é o cabeçalho.
nonisolated struct NoteTable: Equatable, Sendable {
    var rows: [[String]]

    init(rows: [[String]]) {
        let width = max(rows.map(\.count).max() ?? 0, 1)
        self.rows = rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }

    init(text: String) {
        if text.isEmpty {
            self.init(rows: [["", ""], ["", ""]])
        } else {
            self.init(rows: text.components(separatedBy: "\n").map { $0.components(separatedBy: "\t") })
        }
    }

    /// Linhas `| a | b |` de uma tabela Markdown (a linha `|---|` é ignorada).
    init(markdownRows: [String]) {
        let parsed = markdownRows.compactMap { row -> [String]? in
            var cells = row.trimmingCharacters(in: .whitespaces).split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.first == "" { cells.removeFirst() }
            if cells.last == "" { cells.removeLast() }
            let isSeparator = !cells.isEmpty && cells.allSatisfy { cell in
                !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
            }
            return isSeparator ? nil : cells.map { $0.replacingOccurrences(of: "\t", with: " ") }
        }
        self.init(rows: parsed)
    }

    var columnCount: Int { rows.first?.count ?? 0 }

    var text: String {
        rows.map { $0.map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
            .joined(separator: "\t") }.joined(separator: "\n")
    }

    var markdownLines: [String] {
        guard let header = rows.first else { return [] }
        let line = { (cells: [String]) in "| " + cells.map { $0.replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |" }
        return [line(header), line(header.map { _ in "---" })] + rows.dropFirst().map(line)
    }

    mutating func addRow() { rows.append(Array(repeating: "", count: max(columnCount, 1))) }

    mutating func addColumn() {
        if rows.isEmpty { rows = [[""]] }
        for index in rows.indices { rows[index].append("") }
    }

    mutating func removeRow(at index: Int) {
        guard rows.count > 1, rows.indices.contains(index) else { return }
        rows.remove(at: index)
    }

    mutating func removeColumn(at index: Int) {
        guard columnCount > 1 else { return }
        for row in rows.indices where rows[row].indices.contains(index) { rows[row].remove(at: index) }
    }
}

extension Character {
    /// Emoji desenhado como imagem (⚠️, 💡…), e não um dígito ou símbolo de texto.
    nonisolated var isEmojiIcon: Bool {
        guard let scalar = unicodeScalars.first, scalar.properties.isEmoji else { return false }
        return scalar.properties.isEmojiPresentation || unicodeScalars.count > 1
    }
}
