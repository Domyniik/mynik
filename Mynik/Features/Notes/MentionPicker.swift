import SwiftData
import SwiftUI

/// Sugestões ao escrever "@": páginas, projetos, movimentos e datas.
struct MentionPicker: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]

    let query: String
    /// Página onde se escreve (não se sugere a si mesma).
    let current: Note
    let onChoose: (_ label: String, _ target: NoteMention.Target) -> Void

    private func matches(_ text: String) -> Bool {
        query.isEmpty || text.localizedStandardContains(query)
    }

    var body: some View {
        let pages = notes.filter { $0 !== current && !$0.isTemplate && matches($0.title) }.prefix(4)
        let projectMatches = projects.filter { matches($0.name) }.prefix(3)
        let expenses = transactions.filter { matches($0.title) }.prefix(3)
        let dates = NoteMention.dateSuggestions(for: query)

        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                if !pages.isEmpty { header("Páginas") }
                ForEach(Array(pages)) { note in
                    row("\(note.icon) \(note.displayTitle)", symbol: nil) { onChoose(note.displayTitle, .note(note.uid)) }
                }
                if !projectMatches.isEmpty { header("Projetos") }
                ForEach(Array(projectMatches)) { project in
                    row(project.name, symbol: "checklist") { onChoose(project.name, .project(project.uid)) }
                }
                if !expenses.isEmpty { header("Movimentos") }
                ForEach(Array(expenses)) { transaction in
                    row("\(transaction.title) · \(transaction.date.formatted(date: .abbreviated, time: .omitted))",
                        symbol: "eurosign.circle") {
                        onChoose(transaction.title, .transaction(transaction.uid))
                    }
                }
                if !dates.isEmpty { header("Datas") }
                ForEach(dates, id: \.day) { suggestion in
                    row(suggestion.label, symbol: "calendar") {
                        let label = NoteDatabase.date(from: suggestion.day).map(NoteMention.label(for:)) ?? suggestion.label
                        onChoose(label, .date(suggestion.day))
                    }
                }
                if pages.isEmpty, projectMatches.isEmpty, expenses.isEmpty, dates.isEmpty {
                    Text("Sem resultados para \"\(query)\"").foregroundStyle(.secondary).padding(8)
                }
            }
            .padding(4)
        }
        .frame(maxWidth: 360, maxHeight: 260)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }

    private func header(_ title: String) -> some View {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.top, 6)
    }

    private func row(_ title: String, symbol: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 20) }
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Páginas e linhas de bases de dados que mencionam ou têm uma data.
struct DateMentionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var notes: [Note]
    let day: String
    let onOpen: (Note) -> Void

    var body: some View {
        let link = NoteMention.Target.date(day).url
        let mentioning = notes.filter { note in
            note.plainText.contains(link) || note.propertyValues.values.contains(day)
        }
        NavigationStack {
            List {
                if mentioning.isEmpty {
                    Text("Nada neste dia.").foregroundStyle(.secondary)
                }
                ForEach(mentioning) { note in
                    Button("\(note.icon) \(note.displayTitle)") {
                        dismiss()
                        onOpen(note)
                    }
                }
            }
            .navigationTitle(NoteDatabase.date(from: day).map(NoteMention.label(for:)) ?? day)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
            }
        }
        .frame(minWidth: 320, minHeight: 300)
    }
}
