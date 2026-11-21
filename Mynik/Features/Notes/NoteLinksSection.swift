import SwiftData
import SwiftUI

/// Tipo de item a ligar a uma nota.
enum NoteLinkKind: String, Identifiable, CaseIterable {
    case note
    case project
    case transaction

    var id: Self { self }

    var title: String {
        switch self {
        case .note: "Nota"
        case .project: "Projeto"
        case .transaction: "Movimento"
        }
    }

    var symbolName: String {
        switch self {
        case .note: "note.text"
        case .project: "checklist"
        case .transaction: "eurosign.circle"
        }
    }
}

/// Ligações de uma nota: menções `[[…]]`, itens ligados e notas que apontam para ela.
struct NoteLinksSection: View {
    @Query private var notes: [Note]
    @Query private var projects: [Project]

    let note: Note
    let onOpenNote: (Note) -> Void
    let onOpenProject: (Project) -> Void
    let onOpenTransaction: (FinanceTransaction) -> Void

    @State private var pickingKind: NoteLinkKind?

    var body: some View {
        let mentions = NoteLinks.mentions(in: note, notes: notes, projects: projects, excludingLinked: true)
        Section {
            ForEach(mentions.notes) { other in
                noteButton(other, caption: "Mencionada")
            }
            ForEach(mentions.projects) { project in
                projectButton(project, caption: "Mencionado")
            }
            ForEach(mentions.unresolved, id: \.self) { title in
                Label("[[\(title)]] não existe", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
            ForEach(note.linkedNotes ?? []) { other in
                noteButton(other, caption: nil)
                    .swipeActions { unlinkButton { NoteLinks.toggle(other, in: note) } }
            }
            ForEach(note.linkedProjects ?? []) { project in
                projectButton(project, caption: nil)
                    .swipeActions { unlinkButton { NoteLinks.toggle(project, in: note) } }
            }
            ForEach(note.linkedTransactions ?? []) { transaction in
                Button { onOpenTransaction(transaction) } label: {
                    TransactionRow(transaction: transaction)
                }
                .buttonStyle(.plain)
                .contextMenu { unlinkButton { NoteLinks.toggle(transaction, in: note) } }
                .swipeActions { unlinkButton { NoteLinks.toggle(transaction, in: note) } }
            }
            ForEach(note.backlinks ?? []) { other in
                noteButton(other, caption: "Aponta para esta")
            }
            // Menções no texto de outras páginas que ainda não estão ligadas.
            ForEach(NoteMention.backlinks(to: note, among: notes).filter { other in
                !(note.backlinks ?? []).contains { $0 === other }
            }) { other in
                noteButton(other, caption: "Menciona esta")
            }

            Menu {
                ForEach(NoteLinkKind.allCases) { kind in
                    Button("\(kind.title)…", systemImage: kind.symbolName) { pickingKind = kind }
                }
            } label: {
                Label("Ligar a…", systemImage: "link")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
        } header: {
            Text("Ligações")
        } footer: {
            Text("Escreve @ no texto para mencionar uma página, um projeto, um movimento ou uma data ([[Título]] também funciona).")
        }
        .sheet(item: $pickingKind) { kind in
            NoteLinkPicker(note: note, kind: kind)
        }
    }

    private func noteButton(_ other: Note, caption: String?) -> some View {
        Button { onOpenNote(other) } label: {
            LabeledContent {
                if let caption { Text(caption).font(.caption) }
            } label: {
                Label { Text(other.displayTitle) } icon: { Text(other.icon) }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if NoteLinks.isLinked(other, to: note) {
                unlinkButton { NoteLinks.toggle(other, in: note) }
            }
        }
    }

    private func projectButton(_ project: Project, caption: String?) -> some View {
        Button { onOpenProject(project) } label: {
            LabeledContent {
                if let caption { Text(caption).font(.caption) }
            } label: {
                Label(project.name, systemImage: project.symbolName)
                    .foregroundStyle(project.color.color)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if NoteLinks.isLinked(project, to: note) {
                unlinkButton { NoteLinks.toggle(project, in: note) }
            }
        }
    }

    private func unlinkButton(_ action: @escaping () -> Void) -> some View {
        Button("Remover ligação", systemImage: "link.badge.minus", role: .destructive) {
            withAnimation { action() }
        }
    }
}

/// Lista pesquisável para ligar notas, projetos ou movimentos a uma nota.
struct NoteLinkPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]

    let note: Note
    let kind: NoteLinkKind

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                switch kind {
                case .note:
                    ForEach(notes.filter { $0 !== note && matches($0.displayTitle) }) { other in
                        row(isLinked: NoteLinks.isLinked(other, to: note)) {
                            Label { Text(other.displayTitle) } icon: { Text(other.icon) }
                        } action: { NoteLinks.toggle(other, in: note) }
                    }
                case .project:
                    ForEach(projects.filter { matches($0.name) }) { project in
                        row(isLinked: NoteLinks.isLinked(project, to: note)) {
                            Label(project.name, systemImage: project.symbolName)
                        } action: { NoteLinks.toggle(project, in: note) }
                    }
                case .transaction:
                    ForEach(transactions.filter { matches($0.title) }.prefix(200)) { transaction in
                        row(isLinked: NoteLinks.isLinked(transaction, to: note)) {
                            TransactionRow(transaction: transaction)
                        } action: { NoteLinks.toggle(transaction, in: note) }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Ligar \(kind.title.lowercased())")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluído") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    private func matches(_ text: String) -> Bool {
        searchText.isEmpty || text.localizedStandardContains(searchText)
    }

    private func row<Content: View>(isLinked: Bool, @ViewBuilder content: () -> Content, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                content()
                Spacer()
                Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isLinked ? Color.accentColor : .secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isLinked ? .isSelected : [])
    }
}
