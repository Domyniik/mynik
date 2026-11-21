import Foundation
import SwiftData

/// Importa um export do Notion ("Markdown & CSV", em ZIP) para as Notas.
///
/// Formato público do export: cada página é `Título <id>.md`, as subpáginas e
/// imagens ficam numa pasta com o mesmo nome, e cada base de dados é
/// `Título <id>.csv` (ou `…_all.csv`) com as páginas das linhas na pasta.
/// Exports grandes vêm partidos em ZIPs dentro do ZIP.
enum NotionImporter {
    struct Summary: Equatable, Sendable {
        var pages = 0
        var databases = 0
        var rows = 0
        var images = 0
    }

    enum ImportError: LocalizedError {
        case empty

        var errorDescription: String? {
            "O ZIP não tem páginas (.md) nem bases de dados (.csv) do Notion."
        }
    }

    /// Ficheiros lidos do ZIP, prontos a importar (pode correr fora da thread principal).
    struct Files: Sendable {
        var texts: [String: String] = [:]
        /// Imagens já reduzidas a JPEG, por caminho.
        var images: [String: Data] = [:]
    }

    nonisolated static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "webp", "bmp", "tiff"]

    // MARK: 1. Ler o ZIP

    nonisolated static func readFiles(fromZip data: Data, depth: Int = 0) throws -> Files {
        let zip = try ZipReader(data: data)
        var files = Files()
        for entry in zip.entries where !entry.isDirectory {
            let path = entry.path
            if path.hasPrefix("__MACOSX/") || path.hasSuffix(".DS_Store") { continue }
            let ext = (path as NSString).pathExtension.lowercased()
            switch ext {
            case "zip" where depth < 2:
                let inner = try readFiles(fromZip: try zip.contents(of: entry), depth: depth + 1)
                files.texts.merge(inner.texts) { first, _ in first }
                files.images.merge(inner.images) { first, _ in first }
            case "md", "csv":
                let content = try zip.contents(of: entry)
                files.texts[path] = String(data: content, encoding: .utf8) ?? String(data: content, encoding: .isoLatin1) ?? ""
            case _ where imageExtensions.contains(ext):
                if let jpeg = ImageDownsampler.jpegData(from: try zip.contents(of: entry)) {
                    files.images[path] = jpeg
                }
            default:
                continue
            }
        }
        return files
    }

    // MARK: 2. Criar as notas

    /// Nó da árvore: uma página (.md), uma base de dados (.csv) ou as duas.
    private struct Node {
        var key: String
        var markdownPath: String?
        var csvPath: String?
        var depth: Int { key.split(separator: "/").count }
    }

    @MainActor
    static func importFiles(_ files: Files, into context: ModelContext, parent: Note? = nil) throws -> Summary {
        var nodes: [String: Node] = [:]
        let csvPaths = Set(files.texts.keys.filter { $0.lowercased().hasSuffix(".csv") })
        for path in files.texts.keys.sorted() {
            let lower = path.lowercased()
            if lower.hasSuffix(".md") {
                let key = String(path.dropLast(3))
                nodes[key, default: Node(key: key)].markdownPath = path
            } else if lower.hasSuffix(".csv") {
                var key = String(path.dropLast(4))
                if key.hasSuffix("_all") {
                    key = String(key.dropLast(4))
                } else if csvPaths.contains(key + "_all.csv") {
                    continue  // O "_all" tem todas as linhas.
                }
                nodes[key, default: Node(key: key)].csvPath = path
            }
        }
        guard !nodes.isEmpty else { throw ImportError.empty }

        var summary = Summary()
        var created: [String: Note] = [:]
        // Linhas de cada base de dados criadas a partir do CSV, por título limpo.
        var csvRows: [String: [String: Note]] = [:]

        for node in nodes.values.sorted(by: { ($0.depth, $0.key) < ($1.depth, $1.key) }) {
            let parentKey = (node.key as NSString).deletingLastPathComponent
            let parentNote = created[parentKey] ?? parent
            let title = cleanName((node.key as NSString).lastPathComponent)

            // Linha já criada pelo CSV da base de dados: completa-se com o .md.
            var note: Note
            if let existing = csvRows[parentKey]?[title.lowercased()] {
                note = existing
            } else {
                note = NoteEditing.makeNote(title: title, parent: parentNote, in: context)
                note.icon = "📄"
                summary.pages += 1
            }
            created[node.key] = note

            if let csvPath = node.csvPath, let csv = files.texts[csvPath] {
                csvRows[node.key] = makeDatabase(note, csv: csv, in: context, summary: &summary)
            }
            if let mdPath = node.markdownPath, let markdown = files.texts[mdPath] {
                fill(note, markdown: markdown, path: mdPath, files: files, in: context, summary: &summary)
            }
        }
        return summary
    }

    // MARK: Páginas

    @MainActor
    private static func fill(_ note: Note, markdown: String, path: String, files: Files, in context: ModelContext, summary: inout Summary) {
        var (title, body) = splitTitle(markdown)
        if let title, !title.isEmpty { note.title = title }

        // Propriedades no topo de uma linha ("Estado: Feito"), quando a base de dados as tem.
        if let database = note.database {
            let names = Dictionary(database.databaseProperties.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
            let (values, rest) = splitRowProperties(body, knownNames: Set(names.keys))
            for (name, value) in values {
                if let property = names[name.lowercased()], note.value(for: property).isEmpty {
                    note.setValue(normalizedValue(value, type: property.type), for: property)
                }
            }
            body = rest
        }

        let directory = (path as NSString).deletingLastPathComponent
        var parsed = NoteMarkdown.parse(convertPageLinks(body))
        // Imagens: as do ZIP entram como bloco; as da web ficam como link.
        var images: [Int: Data] = [:]
        for index in parsed.indices where parsed[index].kind == .image {
            let reference = parsed[index].imagePath
            if let data = files.images[resolve(reference, relativeTo: directory)] {
                images[index] = data
            } else {
                parsed[index] = .init(kind: .text, text: "[\(parsed[index].text.isEmpty ? reference : parsed[index].text)](\(reference))")
            }
        }

        for block in note.sortedBlocks where block.text.isEmpty && block.kind == .text {
            NoteEditing.deleteBlock(block, from: note, context: context)
        }
        var previous = note.sortedBlocks.last
        for (index, item) in parsed.enumerated() {
            let block = NoteEditing.insertBlock(item.kind, text: item.text, imageData: images[index], after: previous, in: note, context: context)
            block.isChecked = item.isChecked
            if !item.language.isEmpty { block.language = item.language }
            if !item.emoji.isEmpty { block.emoji = item.emoji }
            previous = block
            if images[index] != nil { summary.images += 1 }
        }
        if note.blocks?.isEmpty ?? true { NoteEditing.insertBlock(.text, in: note, context: context) }
    }

    // MARK: Bases de dados

    /// Cria as propriedades e as linhas a partir do CSV; devolve as linhas por título.
    @MainActor
    private static func makeDatabase(_ note: Note, csv: String, in context: ModelContext, summary: inout Summary) -> [String: Note] {
        var table = CSVParser.parse(csv.hasPrefix("\u{FEFF}") ? String(csv.dropFirst()) : csv)
        table.removeAll { $0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        guard let header = table.first, !header.isEmpty else { return [:] }
        let records = Array(table.dropFirst())

        note.isDatabase = true
        note.icon = "🗂️"
        summary.databases += 1
        var properties: [NoteProperty] = []
        for column in 1..<max(header.count, 1) {
            let values = records.map { $0.indices.contains(column) ? $0[column].trimmingCharacters(in: .whitespaces) : "" }
            let name = header[column].trimmingCharacters(in: .whitespaces)
            properties.append(inferProperty(named: name.isEmpty ? "Coluna \(column)" : name, values: values))
        }
        note.databaseProperties = properties
        if !properties.contains(where: { $0.type == .select }), properties.contains(where: { $0.type == .date }) {
            note.databaseView = .calendar
        }

        var rows: [String: Note] = [:]
        for record in records {
            let title = record.first?.trimmingCharacters(in: .whitespaces) ?? ""
            var values: [String: String] = [:]
            for (offset, property) in properties.enumerated() where record.indices.contains(offset + 1) {
                values[property.id] = normalizedValue(record[offset + 1], type: property.type)
            }
            let row = NoteDatabase.addRow(to: note, title: title, values: values, in: context)
            rows[title.lowercased()] = row
            summary.rows += 1
        }
        return rows
    }

    /// Escolhe o tipo da coluna pelos valores: caixa (Yes/No), número, data,
    /// seleção (poucos valores repetidos) ou texto.
    nonisolated static func inferProperty(named name: String, values: [String]) -> NoteProperty {
        let filled = values.filter { !$0.isEmpty }
        guard !filled.isEmpty else { return NoteProperty(name: name, type: .text) }
        let booleans: Set<String> = ["yes", "no", "sim", "não", "true", "false"]
        if filled.allSatisfy({ booleans.contains($0.lowercased()) }) {
            return NoteProperty(name: name, type: .checkbox)
        }
        if filled.allSatisfy({ isNumber($0) }) {
            return NoteProperty(name: name, type: .number)
        }
        if filled.allSatisfy({ parseDate($0) != nil }) {
            return NoteProperty(name: name, type: .date)
        }
        var options: [String] = []
        for value in filled where !options.contains(value) { options.append(value) }
        if options.count < filled.count || options.count <= 3, options.count <= 12, options.allSatisfy({ $0.count <= 40 }) {
            return NoteProperty(name: name, type: .select, options: options)
        }
        return NoteProperty(name: name, type: .text)
    }

    nonisolated static func normalizedValue(_ raw: String, type: NotePropertyType) -> String {
        let value = raw.trimmingCharacters(in: .whitespaces)
        switch type {
        case .checkbox:
            return ["yes", "sim", "true"].contains(value.lowercased()) ? "true" : ""
        case .number:
            return value.replacingOccurrences(of: ",", with: ".").filter { "0123456789.-".contains($0) }
        case .date:
            return parseDate(value).map { NoteDatabase.dateValue($0) } ?? ""
        case .text, .select:
            return value
        }
    }

    // MARK: Auxiliares (puros)

    /// Tira o id do Notion do fim do nome (`Plano 1a2b…` → `Plano`).
    nonisolated static func cleanName(_ name: String) -> String {
        let trimmed = name.replacing(/\s+[0-9a-f]{32}$/, with: "")
        return trimmed.trimmingCharacters(in: .whitespaces)
    }

    /// Separa o `# Título` da primeira linha do resto.
    nonisolated static func splitTitle(_ markdown: String) -> (title: String?, body: String) {
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        guard let first = lines.first, first.hasPrefix("# ") else { return (nil, lines.joined(separator: "\n")) }
        lines.removeFirst()
        return (String(first.dropFirst(2)).trimmingCharacters(in: .whitespaces), lines.joined(separator: "\n"))
    }

    /// Lê as linhas "Nome: valor" do topo de uma página de linha (só nomes conhecidos).
    nonisolated static func splitRowProperties(_ body: String, knownNames: Set<String>) -> (values: [(String, String)], rest: String) {
        var lines = body.components(separatedBy: "\n")
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        var values: [(String, String)] = []
        while let line = lines.first, let colon = line.firstIndex(of: ":") {
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            guard knownNames.contains(name.lowercased()) else { break }
            values.append((name, String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)))
            lines.removeFirst()
        }
        return (values, lines.joined(separator: "\n"))
    }

    /// Links para outras páginas do export viram menções `[[Título]]`.
    nonisolated static func convertPageLinks(_ markdown: String) -> String {
        markdown.replacing(/(!?)\[([^\]\n]+)\]\(([^)\n]+\.(?:md|csv))\)/) { match in
            // Imagens (`![…](…)`) ficam como estão.
            match.output.1.isEmpty ? "[[\(cleanName(String(match.output.2)))]]" : String(match.output.0)
        }
    }

    nonisolated static func resolve(_ reference: String, relativeTo directory: String) -> String {
        let decoded = reference.removingPercentEncoding ?? reference
        var parts = directory.isEmpty ? [] : directory.split(separator: "/").map(String.init)
        for part in decoded.split(separator: "/").map(String.init) {
            if part == ".." { _ = parts.popLast() } else if part != "." { parts.append(part) }
        }
        return parts.joined(separator: "/")
    }

    nonisolated static func isNumber(_ text: String) -> Bool {
        let cleaned = text.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        return !cleaned.isEmpty && Double(cleaned) != nil
    }

    /// Datas como o Notion as exporta ("November 21, 2026", com hora ou
    /// intervalo "… → …") e formatos numéricos comuns.
    nonisolated static func parseDate(_ text: String) -> Date? {
        let start = text.components(separatedBy: " → ").first?.trimmingCharacters(in: .whitespaces) ?? text
        guard !start.isEmpty, start.count <= 40 else { return nil }
        let formats: [(String, String)] = [
            ("en_US_POSIX", "MMMM d, yyyy h:mm a"), ("en_US_POSIX", "MMMM d, yyyy"),
            ("en_US_POSIX", "yyyy-MM-dd"), ("en_US_POSIX", "yyyy/MM/dd"), ("en_US_POSIX", "dd/MM/yyyy"),
            ("pt_PT", "d 'de' MMMM 'de' yyyy"),
        ]
        for (locale, format) in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: locale)
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: start) { return date }
        }
        return nil
    }
}
