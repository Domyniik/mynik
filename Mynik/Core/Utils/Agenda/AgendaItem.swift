import Foundation

/// Algo com data que precisa de atenção: ITV, seguro, documento a expirar, follow-up...
///
/// Alimenta a secção "A vencer" da tela Hoje e as notificações locais.
nonisolated struct AgendaItem: Identifiable, Equatable, Sendable {
    enum Source: String, Sendable {
        case car
        case document
        case career
    }

    /// Chave estável (também usada no identificador das notificações).
    let id: String
    let title: String
    var detail: String = ""
    let date: Date
    let symbolName: String
    let source: Source
    /// Palavra antes do prazo: "Vence", "Expira", "Follow-up"...
    var dueWord: String = "Vence"
    /// Aparece na tela Hoje a partir de quantos dias antes.
    var horizonDays: Int = 30
    /// Dias antes em que se envia uma notificação (`0` = no próprio dia).
    var remindDaysBefore: [Int] = [0]

    func daysUntil(from now: Date = .now, calendar: Calendar = .current) -> Int {
        DueDateText.daysUntil(date, from: now, calendar: calendar)
    }

    func isVisible(from now: Date = .now, calendar: Calendar = .current) -> Bool {
        daysUntil(from: now, calendar: calendar) <= horizonDays
    }

    /// "Vence hoje", "Expira em 12 dias", "Atrasado 3 dias"...
    func describe(from now: Date = .now, calendar: Calendar = .current) -> String {
        switch daysUntil(from: now, calendar: calendar) {
        case ..<(-1): "Atrasado \(-daysUntil(from: now, calendar: calendar)) dias"
        case -1: "Atrasado 1 dia"
        case 0: "\(dueWord) hoje"
        case 1: "\(dueWord) amanhã"
        case let days: "\(dueWord) em \(days) dias"
        }
    }
}

extension [AgendaItem] {
    /// Itens a mostrar agora, do mais urgente para o menos.
    func upcoming(from now: Date = .now, calendar: Calendar = .current) -> [AgendaItem] {
        filter { $0.isVisible(from: now, calendar: calendar) }.sorted { $0.date < $1.date }
    }
}
