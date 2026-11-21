import SwiftData
import SwiftUI

/// Base de dados numa página: escolha da vista, propriedades e linhas.
struct NoteDatabaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var database: Note
    let onOpen: (Note) -> Void

    @State private var renaming: NoteProperty?
    @State private var newName = ""

    var body: some View {
        Section {
            Picker("Vista", selection: $database.databaseViewRaw) {
                ForEach(DatabaseViewKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.symbolName).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch database.databaseView {
            case .table:
                DatabaseTableView(database: database, onOpen: onOpen, onRename: startRenaming)
            case .board:
                DatabaseBoardView(database: database, onOpen: onOpen, onAddRow: addRow)
            case .calendar:
                DatabaseCalendarView(database: database, onOpen: onOpen, onAddRow: addRow)
            }

            HStack {
                Button("Nova linha", systemImage: "plus") { addRow() }
                Spacer()
                Menu("Propriedade", systemImage: "plus.square.on.square") {
                    ForEach(NotePropertyType.allCases) { type in
                        Button(type.title, systemImage: type.symbolName) {
                            startRenaming(NoteDatabase.addProperty(type, to: database))
                        }
                    }
                }
                .menuStyle(.button)
                .fixedSize()
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Base de dados · \(database.sortedChildren.count) linhas")
        }
        .alert("Nome da propriedade", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nome", text: $newName)
            Button("Guardar") {
                guard var property = renaming else { return }
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { property.name = name }
                NoteDatabase.update(property, in: database)
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func startRenaming(_ property: NoteProperty) {
        newName = property.name
        renaming = property
    }

    private func addRow(_ values: [String: String] = [:]) {
        let row = NoteDatabase.addRow(to: database, values: values, in: modelContext)
        try? modelContext.save()
        onOpen(row)
    }
}

// MARK: - Tabela

struct DatabaseTableView: View {
    @Environment(\.modelContext) private var modelContext
    let database: Note
    let onOpen: (Note) -> Void
    let onRename: (NoteProperty) -> Void

    private let columnWidth: CGFloat = 150

    var body: some View {
        let properties = database.databaseProperties
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Nome").frame(width: 180, alignment: .leading)
                    ForEach(properties) { property in
                        header(property)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(database.sortedChildren) { row in
                    GridRow {
                        Button { onOpen(row) } label: {
                            Text("\(row.icon) \(row.displayTitle)")
                                .lineLimit(1)
                                .frame(width: 180, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.primary)
                        ForEach(properties) { property in
                            PropertyValueEditor(row: row, property: property) { option in
                                var updated = property
                                updated.options.append(option)
                                NoteDatabase.update(updated, in: database)
                            }
                            .frame(width: columnWidth, alignment: .leading)
                        }
                    }
                    .contextMenu {
                        Button("Abrir", systemImage: "arrow.up.right") { onOpen(row) }
                        Button("Apagar linha", systemImage: "trash", role: .destructive) {
                            modelContext.delete(row)
                            try? modelContext.save()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        if database.sortedChildren.isEmpty {
            Text("Sem linhas. Cria uma com \"Nova linha\".")
                .foregroundStyle(.secondary)
        }
    }

    private func header(_ property: NoteProperty) -> some View {
        Menu {
            Button("Mudar o nome…", systemImage: "pencil") { onRename(property) }
            Button("Apagar propriedade", systemImage: "trash", role: .destructive) {
                NoteDatabase.removeProperty(property, from: database)
            }
        } label: {
            Label(property.name, systemImage: property.type.symbolName)
                .lineLimit(1)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .frame(width: columnWidth, alignment: .leading)
    }
}

// MARK: - Quadro

struct DatabaseBoardView: View {
    let database: Note
    let onOpen: (Note) -> Void
    let onAddRow: ([String: String]) -> Void

    var body: some View {
        if let property = NoteDatabase.boardProperty(of: database) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(NoteDatabase.boardColumns(of: database, by: property)) { column in
                        boardColumn(column, property: property)
                    }
                }
                .padding(.vertical, 4)
            }
        } else {
            Text("Acrescenta uma propriedade de seleção para agrupar o quadro.")
                .foregroundStyle(.secondary)
        }
    }

    private func boardColumn(_ column: NoteDatabase.BoardColumn, property: NoteProperty) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SelectTag(text: column.option.isEmpty ? "Sem \(property.name.lowercased())" : column.option)
                Text("\(column.rows.count)").foregroundStyle(.secondary).font(.caption)
            }
            ForEach(column.rows) { row in
                Button { onOpen(row) } label: { card(row, grouping: property) }
                    .buttonStyle(.plain)
                    .draggable(row.uid)
                    .contextMenu {
                        ForEach(property.options.filter { $0 != column.option }, id: \.self) { option in
                            Button("Mover para \(option)") { row.setValue(option, for: property) }
                        }
                    }
            }
            Button("Nova", systemImage: "plus") {
                onAddRow(column.option.isEmpty ? [:] : [property.id: column.option])
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(10)
        .frame(width: 220, alignment: .topLeading)
        .background(.fill.quaternary, in: .rect(cornerRadius: 12))
        .dropDestination(for: String.self) { uids, _ in
            let rows = database.sortedChildren.filter { uids.contains($0.uid) }
            rows.forEach { $0.setValue(column.option, for: property) }
            return !rows.isEmpty
        }
    }

    private func card(_ row: Note, grouping: NoteProperty) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(row.icon) \(row.displayTitle)").fontWeight(.medium).lineLimit(2)
            ForEach(database.databaseProperties.filter { $0.id != grouping.id && !row.value(for: $0).isEmpty }) { property in
                DatabaseValueLabel(property: property, value: row.value(for: property))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
    }
}

/// Valor só de leitura (cartões e calendário).
struct DatabaseValueLabel: View {
    let property: NoteProperty
    let value: String

    var body: some View {
        switch property.type {
        case .select:
            SelectTag(text: value)
        case .checkbox:
            Label(property.name, systemImage: value == "true" ? "checkmark.square.fill" : "square")
                .font(.caption)
        case .date:
            Label(NoteDatabase.date(from: value)?.formatted(date: .abbreviated, time: .omitted) ?? value, systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .text, .number:
            Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

// MARK: - Calendário

struct DatabaseCalendarView: View {
    let database: Note
    let onOpen: (Note) -> Void
    let onAddRow: ([String: String]) -> Void

    @State private var month = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        if let property = NoteDatabase.dateProperty(of: database) {
            VStack(spacing: 10) {
                HStack {
                    Button("Mês anterior", systemImage: "chevron.left") { shiftMonth(-1) }
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button("Mês seguinte", systemImage: "chevron.right") { shiftMonth(1) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(["S", "T", "Q", "Q", "S", "S", "D"].indices, id: \.self) { index in
                        Text(["S", "T", "Q", "Q", "S", "S", "D"][index])
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(NoteDatabase.monthGrid(for: month), id: \.self) { day in
                        dayCell(day, property: property)
                    }
                }

                dayDetail(property: property)
            }
        } else {
            Text("Acrescenta uma propriedade de data para ver o calendário.")
                .foregroundStyle(.secondary)
        }
    }

    private func dayCell(_ day: Date, property: NoteProperty) -> some View {
        let calendar = Calendar.current
        let rows = NoteDatabase.rows(of: database, on: day, by: property)
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        return Button { selectedDay = day } label: {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.day()))
                    .font(.callout)
                    .fontWeight(calendar.isDateInToday(day) ? .bold : .regular)
                    .foregroundStyle(inMonth ? .primary : .tertiary)
                HStack(spacing: 2) {
                    ForEach(rows.prefix(3)) { _ in
                        Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(rows.count) itens")
    }

    private func dayDetail(property: NoteProperty) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedDay.formatted(date: .complete, time: .omitted))
                .font(.subheadline.weight(.semibold))
            ForEach(NoteDatabase.rows(of: database, on: selectedDay, by: property)) { row in
                Button("\(row.icon) \(row.displayTitle)") { onOpen(row) }
                    .buttonStyle(.borderless)
            }
            Button("Nova neste dia", systemImage: "plus") {
                onAddRow([property.id: NoteDatabase.dateValue(selectedDay)])
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shiftMonth(_ offset: Int) {
        month = Calendar.current.date(byAdding: .month, value: offset, to: month) ?? month
    }
}
