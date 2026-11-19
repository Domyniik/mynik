import Foundation

/// Parser de CSV simples: deteta o separador e respeita campos entre aspas.
nonisolated enum CSVParser {
    static func parse(_ text: String) -> [[String]] {
        let delimiter = detectDelimiter(in: text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()
        var pending: Character?

        func endField() {
            row.append(field.trimmingCharacters(in: .whitespaces))
            field = ""
        }

        func endRow() {
            endField()
            if row.contains(where: { !$0.isEmpty }) {
                rows.append(row)
            }
            row = []
        }

        while let character = pending ?? iterator.next() {
            pending = nil
            if isQuoted {
                if character == "\"" {
                    let next = iterator.next()
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        isQuoted = false
                        pending = next
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                isQuoted = true
            } else if character == delimiter {
                endField()
            } else if character.isNewline {
                endRow()
            } else {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            endRow()
        }
        return rows
    }

    /// Escolhe entre `;`, `,` e tab, conforme o que mais aparece na 1.ª linha.
    static func detectDelimiter(in text: String) -> Character {
        let firstLine = text.prefix { !$0.isNewline }
        let candidates: [Character] = [";", "\t", ","]
        return candidates.max { a, b in
            firstLine.filter { $0 == a }.count < firstLine.filter { $0 == b }.count
        } ?? ","
    }
}
