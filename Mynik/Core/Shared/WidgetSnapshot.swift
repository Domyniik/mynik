import Foundation

/// Resumo que a app deixa no App Group para os widgets (e o menu do Mac) lerem.
///
/// Os widgets não abrem a base de dados: a app escreve este ficheiro pequeno
/// sempre que os dados mudam e pede ao WidgetKit para atualizar.
/// Partilhado entre a app e a extensão `MynikWidgets`.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// Vem do Info.plist: `group.com.domynik.mynik` no iOS, `<TeamID>.com.domynik.mynik` no Mac.
    static let appGroupID = Bundle.main.object(forInfoDictionaryKey: "MynikAppGroup") as? String ?? "group.com.domynik.mynik"

    struct BillItem: Codable, Equatable, Sendable, Identifiable {
        var id: String
        var title: String
        var amount: Decimal
        var currencyCode: String
        var dueDate: Date
    }

    var generatedAt = Date.now
    /// Início do mês resumido.
    var month = Date.now
    var income: Decimal = 0
    var expenses: Decimal = 0
    /// Contas por pagar (atrasadas e próximas), por data de vencimento.
    var bills: [BillItem] = []

    var balance: Decimal { income - expenses }

    /// Contas que vencem até `days` dias depois de `now` (inclui as atrasadas).
    func bills(within days: Int, from now: Date = .now, calendar: Calendar = .current) -> [BillItem] {
        bills.filter { DueDateText.daysUntil($0.dueDate, from: now, calendar: calendar) <= days }
    }

    /// "novembro", para o título do saldo.
    var monthName: String {
        month.formatted(.dateTime.month(.wide).locale(.app))
    }

    // MARK: - Ficheiro no App Group

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "widget-snapshot.json")
    }

    static func load(from url: URL? = fileURL) -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Grava o resumo; devolve `false` se o App Group não estiver disponível.
    @discardableResult
    func save(to url: URL? = fileURL) throws -> Bool {
        guard let url else { return false }
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
        return true
    }

    /// Dados de exemplo para a galeria de widgets.
    static let preview = WidgetSnapshot(
        month: .now,
        income: 1850,
        expenses: 1236.40,
        bills: [
            BillItem(id: "1", title: "Renda", amount: 750, currencyCode: "EUR", dueDate: .now.addingTimeInterval(2 * 86_400)),
            BillItem(id: "2", title: "Luz", amount: 48.90, currencyCode: "EUR", dueDate: .now.addingTimeInterval(5 * 86_400)),
            BillItem(id: "3", title: "Spotify", amount: 10.99, currencyCode: "EUR", dueDate: .now.addingTimeInterval(9 * 86_400)),
        ]
    )
}
