import Foundation

/// Markdown nas notas: formatação inline, menções `[[Título]]`, atalhos ao
/// escrever e exportação/importação de páginas.
nonisolated enum NoteMarkdown {
    /// Bloco lido de um texto Markdown.
    struct ParsedBlock: Equatable {
        var kind: NoteBlockKind
        var text: String
        var isChecked = false
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

    /// Converte o início de um parágrafo no tipo de bloco certo:
    /// `# ` → título, `[] ` ou `- [ ] ` → checklist, `- [x] ` → checklist feito.
    static func shortcut(for text: String) -> ParsedBlock? {
        let rules: [(prefix: String, kind: NoteBlockKind, checked: Bool)] = [
            ("### ", .heading, false), ("## ", .heading, false), ("# ", .heading, false),
            ("- [ ] ", .checklist, false), ("- [x] ", .checklist, true), ("- [X] ", .checklist, true),
            ("[] ", .checklist, false), ("[ ] ", .checklist, false),
        ]
        for rule in rules where text.hasPrefix(rule.prefix) {
            return ParsedBlock(kind: rule.kind, text: String(text.dropFirst(rule.prefix.count)), isChecked: rule.checked)
        }
        return nil
    }

    // MARK: Exportar e importar

    /// Página em Markdown: título como `#`, títulos de bloco como `##`,
    /// checklist como `- [ ]` e imagens pela legenda.
    static func export(title: String, blocks: [NoteBlock]) -> String {
        var lines: [String] = ["# \(title)"]
        var previous: NoteBlockKind?
        for block in blocks {
            // Itens de checklist seguidos ficam numa só lista.
            if !(previous == .checklist && block.kind == .checklist) { lines.append("") }
            switch block.kind {
            case .text: lines.append(block.text)
            case .heading: lines.append("## \(block.text)")
            case .checklist: lines.append("- [\(block.isChecked ? "x" : " ")] \(block.text)")
            case .image: lines.append("![\(block.text)](imagem)")
            }
            previous = block.kind
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Lê Markdown em blocos: títulos (`#`…), checklist (`- [ ]`) e parágrafos
    /// (linhas seguidas juntam-se; uma linha vazia separa parágrafos).
    static func parse(_ markdown: String) -> [ParsedBlock] {
        var blocks: [ParsedBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(ParsedBlock(kind: .text, text: paragraph.joined(separator: "\n")))
                paragraph = []
            }
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
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
