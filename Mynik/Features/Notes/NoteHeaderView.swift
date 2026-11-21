import SwiftUI

extension NoteCover {
    var gradient: LinearGradient {
        LinearGradient(
            colors: colors.map { Color(red: $0.red, green: $0.green, blue: $0.blue) },
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

/// Topo de uma página: capa, caminho (breadcrumbs), ícone e título.
struct NoteHeaderView: View {
    @Bindable var note: Note
    var focus: FocusState<String?>.Binding
    let onOpen: (Note) -> Void

    @State private var isEditingIcon = false
    @State private var customIcon = ""
    @State private var isChoosingCover = false

    static let icons = ["📄", "📝", "💡", "📚", "🗂️", "✅", "🎯", "💼", "🏠", "🚗", "✈️", "💰", "🛍️", "❤️", "🧠", "📅", "📊", "🧾", "🗓️", "⭐️"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let cover = note.cover {
                cover.gradient
                    .frame(height: 120)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(alignment: .bottomTrailing) { coverMenu.padding(8) }
                    .accessibilityLabel("Capa \(cover.title)")
            }
            if !note.ancestors.isEmpty {
                breadcrumbs
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                iconMenu
                TextField("Sem título", text: $note.title, axis: .vertical)
                    .font(.largeTitle.bold())
                    .focused(focus, equals: "title")
            }
            if note.cover == nil {
                coverMenu
            }
        }
        .alert("Ícone da página", isPresented: $isEditingIcon) {
            TextField("Emoji", text: $customIcon)
            Button("Usar") {
                if let first = customIcon.trimmingCharacters(in: .whitespaces).first {
                    note.icon = String(first)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Escreve ou cola um emoji.")
        }
    }

    /// Caminho até à página; cada nível abre a página correspondente.
    private var breadcrumbs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(note.ancestors) { ancestor in
                    Button { onOpen(ancestor) } label: {
                        Text("\(ancestor.icon) \(ancestor.displayTitle)").lineLimit(1)
                    }
                    .buttonStyle(.borderless)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text(note.displayTitle).lineLimit(1).foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Caminho")
    }

    private var iconMenu: some View {
        Menu {
            ForEach(Self.icons, id: \.self) { icon in
                Button(icon) { note.icon = icon }
            }
            Divider()
            Button("Outro emoji…", systemImage: "face.smiling") {
                customIcon = ""
                isEditingIcon = true
            }
        } label: {
            Text(note.icon).font(.largeTitle)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .fixedSize()
        .accessibilityLabel("Ícone da página")
    }

    private var coverMenu: some View {
        Button {
            isChoosingCover = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "photo.artframe")
                Text(note.cover == nil ? "Adicionar capa" : "Mudar capa")
                    .lineLimit(1)
            }
            .font(.caption)
                .padding(.horizontal, note.cover == nil ? 0 : 10)
                .padding(.vertical, note.cover == nil ? 0 : 6)
                .background(note.cover == nil ? AnyShapeStyle(.clear) : AnyShapeStyle(.regularMaterial), in: .capsule)
        }
        .buttonStyle(.borderless)
        .fixedSize(horizontal: true, vertical: false)
        .confirmationDialog("Capa", isPresented: $isChoosingCover) {
            ForEach(NoteCover.allCases) { cover in
                Button(cover.title) { withAnimation { note.cover = cover } }
            }
            if note.cover != nil {
                Button("Remover capa", role: .destructive) { withAnimation { note.cover = nil } }
            }
        }
    }
}
