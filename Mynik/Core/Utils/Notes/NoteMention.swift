import Foundation

/// Menções `@` nas notas: links Markdown `[@Etiqueta](mynik://tipo/id)` para
/// páginas, projetos, movimentos e datas.
nonisolated enum NoteMention {
    enum Target: Equatable, Hashable, Sendable {
        case note(String)
        case project(String)
        case transaction(String)
        /// Data `aaaa-mm-dd`.
        case date(String)
        /// Menção antiga `[[Título]]`, resolvida pelo título.
        case title(String)

        var url: String {
            switch self {
            case .note(let uid): "mynik://note/\(uid)"
            case .project(let uid): "mynik://project/\(uid)"
            case .transaction(let uid): "mynik://transaction/\(uid)"
            case .date(let day): "mynik://date/\(day)"
            case .title(let title):
                "mynik://mention/\(title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title)"
            }
        }
    }

    /// Destino de um link tocado numa nota (`nil` se não for uma menção).
    static func target(from url: URL) -> Target? {
        guard url.scheme == "mynik", let host = url.host() else { return nil }
        let value = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/")).removingPercentEncoding ?? ""
        guard !value.isEmpty else { return nil }
        return switch host {
        case "note": .note(value)
        case "project": .project(value)
        case "transaction": .transaction(value)
        case "date": .date(value)
        case "mention": .title(value)
        default: nil
        }
    }

    /// Texto Markdown da menção.
    static func token(label: String, target: Target) -> String {
        let clean = label.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
        return "[@\(clean)](\(target.url))"
    }

    /// Menções `@` (com id) presentes num texto, sem repetidos.
    static func targets(in text: String) -> [Target] {
        var seen = Set<Target>()
        return text.matches(of: linkPattern).compactMap { match in
            guard let url = URL(string: String(match.output.1)), let target = target(from: url),
                  seen.insert(target).inserted else { return nil }
            return target
        }
    }

    nonisolated(unsafe) private static let linkPattern = /\]\((mynik:\/\/[^)\s]+)\)/
    nonisolated(unsafe) private static let queryPattern = /(?:^|\s)@([^\s@\[\]()]{0,30})$/

    // MARK: Escrever "@…"

    /// Pesquisa depois de um "@" no fim do texto (início ou depois de um espaço).
    static func activeQuery(in text: String) -> String? {
        text.firstMatch(of: queryPattern).map { String($0.output.1) }
    }

    /// Troca o "@pesquisa" final pela menção (seguida de espaço).
    static func replacingActiveQuery(in text: String, with token: String) -> String {
        guard let query = activeQuery(in: text) else { return text + token + " " }
        return String(text.dropLast(query.count + 1)) + token + " "
    }

    // MARK: Datas

    struct DateSuggestion: Equatable, Sendable {
        var label: String
        var day: String
    }

    /// Hoje, amanhã, ontem e datas escritas como `dd/mm` ou `dd/mm/aaaa`.
    static func dateSuggestions(for query: String, now: Date = .now, calendar: Calendar = .current) -> [DateSuggestion] {
        let folded = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let relative: [(String, Int)] = [("hoje", 0), ("amanha", 1), ("ontem", -1)]
        var result: [DateSuggestion] = relative.compactMap { name, offset in
            guard folded.isEmpty || name.hasPrefix(folded),
                  let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let label = ["hoje": "Hoje", "amanha": "Amanhã", "ontem": "Ontem"][name] ?? name
            return DateSuggestion(label: label, day: NoteDatabase.dateValue(day, calendar: calendar))
        }
        let parts = query.split(separator: "/").compactMap { Int($0) }
        if parts.count >= 2, (1...31).contains(parts[0]), (1...12).contains(parts[1]) {
            var year = parts.count == 3 ? parts[2] : calendar.component(.year, from: now)
            if year < 100 { year += 2000 }
            if let date = calendar.date(from: DateComponents(year: year, month: parts[1], day: parts[0])) {
                result.append(DateSuggestion(label: label(for: date), day: NoteDatabase.dateValue(date, calendar: calendar)))
            }
        }
        return result
    }

    static func label(for date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "pt_PT")))
    }

    // MARK: Backlinks

    /// Notas que mencionam `note` (por `@` com o id ou por `[[Título]]`).
    @MainActor
    static func backlinks(to note: Note, among notes: [Note]) -> [Note] {
        let link = Target.note(note.uid).url
        let title = note.title.trimmingCharacters(in: .whitespaces).lowercased()
        return notes.filter { other in
            guard other !== note else { return false }
            let text = other.plainText
            if text.contains(link) { return true }
            return !title.isEmpty && NoteMarkdown.mentions(in: text).contains { $0.lowercased() == title }
        }
    }
}
