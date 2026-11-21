import Foundation
import SwiftData

/// Tipo de uma propriedade de base de dados.
nonisolated enum NotePropertyType: String, Codable, CaseIterable, Identifiable, Sendable {
    case text, number, select, date, checkbox

    var id: Self { self }

    var title: String {
        switch self {
        case .text: "Texto"
        case .number: "Número"
        case .select: "Seleção"
        case .date: "Data"
        case .checkbox: "Caixa"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .number: "number"
        case .select: "list.bullet.circle"
        case .date: "calendar"
        case .checkbox: "checkmark.square"
        }
    }
}

/// Coluna de uma base de dados. O título da linha é sempre o título da página.
nonisolated struct NoteProperty: Codable, Identifiable, Hashable, Sendable {
    var id: String = UUID().uuidString
    var name: String
    var type: NotePropertyType
    /// Opções de uma seleção, pela ordem das colunas do quadro.
    var options: [String] = []
}

/// Vista de uma base de dados.
nonisolated enum DatabaseViewKind: String, CaseIterable, Identifiable, Sendable {
    case table, board, calendar

    var id: Self { self }

    var title: String {
        switch self {
        case .table: "Tabela"
        case .board: "Quadro"
        case .calendar: "Calendário"
        }
    }

    var symbolName: String {
        switch self {
        case .table: "tablecells"
        case .board: "rectangle.split.3x1"
        case .calendar: "calendar"
        }
    }
}

extension Note {
    /// Propriedades (colunas), se a página for uma base de dados.
    var databaseProperties: [NoteProperty] {
        get { NoteDatabase.decode([NoteProperty].self, from: databaseSchemaJSON) ?? [] }
        set { databaseSchemaJSON = NoteDatabase.encode(newValue) }
    }

    /// Valores desta linha, por id da propriedade (texto; ver `NoteDatabase`).
    var propertyValues: [String: String] {
        get { NoteDatabase.decode([String: String].self, from: propertyValuesJSON) ?? [:] }
        set { propertyValuesJSON = NoteDatabase.encode(newValue.filter { !$0.value.isEmpty }) }
    }

    var databaseView: DatabaseViewKind {
        get { DatabaseViewKind(rawValue: databaseViewRaw) ?? .table }
        set { databaseViewRaw = newValue.rawValue }
    }

    /// A base de dados a que esta página pertence como linha.
    var database: Note? {
        parent?.isDatabase == true ? parent : nil
    }

    func value(for property: NoteProperty) -> String {
        propertyValues[property.id] ?? ""
    }

    func setValue(_ value: String, for property: NoteProperty) {
        var values = propertyValues
        values[property.id] = value
        propertyValues = values
        updatedAt = .now
    }
}

/// Operações das bases de dados: criar, acrescentar linhas e agrupar para as vistas.
///
/// Os valores guardam-se como texto: números com ponto (`12.5`), datas como
/// `aaaa-mm-dd` e caixas como `true`/`false`.
enum NoteDatabase {
    /// Cria uma base de dados com as propriedades "Estado" e "Data".
    @discardableResult
    static func makeDatabase(title: String = "", parent: Note? = nil, in context: ModelContext) -> Note {
        let note = NoteEditing.makeNote(title: title, parent: parent, in: context)
        note.icon = "🗂️"
        note.isDatabase = true
        note.databaseProperties = [
            NoteProperty(name: "Estado", type: .select, options: ["A fazer", "Em curso", "Feito"]),
            NoteProperty(name: "Data", type: .date),
        ]
        return note
    }

    /// Acrescenta uma linha (subpágina) com valores iniciais.
    @discardableResult
    static func addRow(to database: Note, title: String = "", values: [String: String] = [:], in context: ModelContext) -> Note {
        let row = NoteEditing.makeNote(title: title, parent: database, in: context)
        row.propertyValues = values
        NoteEditing.touch(database)
        return row
    }

    static func addProperty(_ type: NotePropertyType, named name: String? = nil, to database: Note) -> NoteProperty {
        var property = NoteProperty(name: name ?? type.title, type: type)
        if type == .select { property.options = ["Opção 1"] }
        database.databaseProperties.append(property)
        return property
    }

    static func update(_ property: NoteProperty, in database: Note) {
        var properties = database.databaseProperties
        guard let index = properties.firstIndex(where: { $0.id == property.id }) else { return }
        properties[index] = property
        database.databaseProperties = properties
    }

    /// Apaga a propriedade e os valores dela em todas as linhas.
    static func removeProperty(_ property: NoteProperty, from database: Note) {
        database.databaseProperties.removeAll { $0.id == property.id }
        for row in database.sortedChildren where row.propertyValues[property.id] != nil {
            var values = row.propertyValues
            values[property.id] = nil
            row.propertyValues = values
        }
    }

    // MARK: Quadro

    struct BoardColumn: Identifiable, Equatable {
        /// Opção da seleção (vazio = sem valor).
        var option: String
        var rows: [Note]
        var id: String { option }
    }

    /// Primeira propriedade de seleção (agrupa o quadro).
    static func boardProperty(of database: Note) -> NoteProperty? {
        database.databaseProperties.first { $0.type == .select }
    }

    /// Colunas do quadro: uma por opção e, se houver linhas sem valor, "Sem valor" no início.
    static func boardColumns(of database: Note, by property: NoteProperty) -> [BoardColumn] {
        let rows = database.sortedChildren
        var columns = property.options.map { option in
            BoardColumn(option: option, rows: rows.filter { $0.value(for: property) == option })
        }
        let loose = rows.filter { !property.options.contains($0.value(for: property)) }
        if !loose.isEmpty { columns.insert(BoardColumn(option: "", rows: loose), at: 0) }
        return columns
    }

    // MARK: Calendário

    /// Primeira propriedade de data (posiciona as linhas no calendário).
    static func dateProperty(of database: Note) -> NoteProperty? {
        database.databaseProperties.first { $0.type == .date }
    }

    static func dateValue(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(from value: String, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Linhas com a data num dia.
    static func rows(of database: Note, on day: Date, by property: NoteProperty, calendar: Calendar = .current) -> [Note] {
        let key = dateValue(day, calendar: calendar)
        return database.sortedChildren.filter { $0.value(for: property) == key }
    }

    /// Dias a mostrar na grelha de um mês (semanas completas, a começar à segunda).
    static func monthGrid(for month: Date, calendar: Calendar = .current) -> [Date] {
        var calendar = calendar
        calendar.firstWeekday = 2
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: interval.start),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay)
        else { return [] }
        var days: [Date] = []
        var day = firstWeek.start
        while day < lastWeek.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? lastWeek.end
        }
        return days
    }

    // MARK: Números e JSON

    static func number(from value: String) -> Decimal? {
        Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    nonisolated static func decode<T: Decodable>(_ type: T.Type, from json: String) -> T? {
        guard !json.isEmpty else { return nil }
        return try? JSONDecoder().decode(type, from: Data(json.utf8))
    }

    nonisolated static func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}
