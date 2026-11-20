import Foundation
import SwiftData

/// Um resultado da busca global (⌘K).
struct SearchResult: Identifiable, Equatable {
    enum Target: Equatable {
        case section(AppSection)
        /// Abre o formulário do movimento.
        case transaction(PersistentIdentifier)
    }

    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let target: Target
    /// Quanto menor, mais acima (0 = título começa pela pesquisa).
    let rank: Int
}

/// Pontuação de texto: começa por (0), palavra que começa por (1), contém (2).
nonisolated enum SearchMatcher {
    static func rank(_ query: String, in fields: [String]) -> Int? {
        let key = query.searchKey.lowercased()
        guard !key.isEmpty else { return nil }
        var best: Int?
        for (index, field) in fields.enumerated() {
            let text = field.searchKey.lowercased()
            guard !text.isEmpty else { continue }
            // Campos secundários (notas, descrições) valem menos.
            let penalty = index == 0 ? 0 : 3
            let score: Int? = if text.hasPrefix(key) {
                0
            } else if text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(key) }) {
                1
            } else if text.contains(key) {
                2
            } else {
                nil
            }
            if let score { best = min(best ?? .max, score + penalty) }
        }
        return best
    }
}

/// Procura em todos os módulos. Os números dos documentos nunca entram (ficam atrás do Face ID).
@MainActor
enum GlobalSearch {
    static let limit = 40

    static func search(_ query: String, in context: ModelContext) -> [SearchResult] {
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { return [] }
        var results: [SearchResult] = []

        func add(_ id: String, _ title: String, _ subtitle: String, _ symbol: String, _ target: SearchResult.Target, fields: [String]) {
            guard let rank = SearchMatcher.rank(query, in: fields) else { return }
            results.append(SearchResult(id: id, title: title, subtitle: subtitle, symbolName: symbol, target: target, rank: rank))
        }
        func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }
        let date = Date.FormatStyle.dateTime.day().month(.abbreviated).year().locale(.app)

        for section in AppSection.allCases {
            add("section-\(section.rawValue)", section.title, "Secção", section.symbolName, .section(section), fields: [section.title])
        }
        for t in fetch(FinanceTransaction.self) {
            add("tx-\(t.uid)", t.title, "\(Currency.format(t.signedAmount, code: t.currencyCode)) · \(t.date.formatted(date))",
                t.category?.symbolName ?? "eurosign.circle", .transaction(t.persistentModelID),
                fields: [t.title, t.category?.name ?? "", t.notes])
        }
        for b in fetch(Bill.self) {
            add("bill-\(b.uid)", b.title, "Conta a pagar · \(Currency.format(b.amount, code: b.currencyCode))",
                "calendar.badge.clock", .section(.finance), fields: [b.title, b.notes])
        }
        for n in fetch(Note.self) {
            let text = (n.blocks ?? []).map(\.text).joined(separator: " ")
            add("note-\(n.uid)", n.displayTitle, "Nota", "note.text", .section(.notes), fields: [n.displayTitle, text])
        }
        for p in fetch(Project.self) {
            add("project-\(p.uid)", p.name, "Projeto", p.symbolName, .section(.projects), fields: [p.name])
        }
        for task in fetch(ProjectTask.self) {
            add("task-\(task.uid)", task.title, task.project.map { "Tarefa · \($0.name)" } ?? "Tarefa",
                task.isDone ? "checkmark.circle" : "circle", .section(.projects), fields: [task.title, task.notes])
        }
        for g in fetch(Goal.self) {
            add("goal-\(g.uid)", g.title, "Meta", g.symbolName, .section(.goals), fields: [g.title])
        }
        for h in fetch(Habit.self) where !h.isArchived {
            add("habit-\(h.uid)", h.name, "Hábito", h.symbolName, .section(.habits), fields: [h.name])
        }
        for v in fetch(Vehicle.self) {
            add("vehicle-\(v.uid)", v.displayName, "Carro", "car", .section(.car), fields: [v.name, v.plate])
        }
        for d in fetch(PersonalDocument.self) {
            add("doc-\(d.uid)", d.title, "Documento", d.kind.symbolName, .section(.documents), fields: [d.title, d.kind.title])
        }
        for a in fetch(JobApplication.self) {
            add("job-\(a.uid)", "\(a.company) — \(a.role)", "Candidatura", "briefcase", .section(.career), fields: [a.company, a.role])
        }
        for c in fetch(Course.self) {
            add("course-\(c.uid)", c.title, "Curso", "graduationcap", .section(.career), fields: [c.title, c.provider])
        }
        for i in fetch(Investment.self) {
            add("inv-\(i.uid)", i.name, "Investimento", "chart.line.uptrend.xyaxis", .section(.investments), fields: [i.name, i.ticker])
        }
        for product in fetch(StoreProduct.self) {
            add("product-\(product.shopifyID)", product.title, "Produto da loja", "storefront", .section(.store), fields: [product.title])
        }

        return Array(results.sorted { ($0.rank, $0.title) < ($1.rank, $1.title) }.prefix(limit))
    }
}
