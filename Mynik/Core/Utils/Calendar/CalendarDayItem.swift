import Foundation

/// Evento do Calendário ou lembrete, já pronto para a tela Hoje (sem tipos do EventKit).
nonisolated struct CalendarDayItem: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case event(start: Date, end: Date, isAllDay: Bool)
        /// `due` nil: lembrete sem data (não aparece em Hoje).
        case reminder(due: Date?, hasTime: Bool)
    }

    var id: String
    var title: String
    var kind: Kind
    /// Cor do calendário / lista (componentes RGB 0...1).
    var color: [Double] = []
    var location: String = ""

    var isReminder: Bool {
        if case .reminder = kind { true } else { false }
    }

    /// Momento usado para ordenar: início do evento, vencimento do lembrete.
    var sortDate: Date {
        switch kind {
        case .event(let start, _, _): start
        case .reminder(let due, _): due ?? .distantFuture
        }
    }

    /// "Todo o dia", "09:00 – 10:30", "Até às 18:00", "Atrasado desde 12/11"...
    func timeText(on day: Date, calendar: Calendar = .current) -> String {
        let time = Date.FormatStyle(date: .omitted, time: .shortened).locale(.app)
        switch kind {
        case .event(let start, let end, let isAllDay):
            if isAllDay { return "Todo o dia" }
            let startsToday = calendar.isDate(start, inSameDayAs: day)
            let endsToday = calendar.isDate(end, inSameDayAs: day)
            switch (startsToday, endsToday) {
            case (true, true): return "\(start.formatted(time)) – \(end.formatted(time))"
            case (true, false): return "Desde as \(start.formatted(time))"
            case (false, true): return "Até às \(end.formatted(time))"
            case (false, false): return "Todo o dia"
            }
        case .reminder(let due, let hasTime):
            guard let due else { return "" }
            if calendar.startOfDay(for: due) < calendar.startOfDay(for: day) {
                return "Atrasado desde \(due.formatted(.dateTime.day().month(.twoDigits).locale(.app)))"
            }
            return hasTime ? "Até às \(due.formatted(time))" : "Hoje"
        }
    }

    /// Eventos primeiro (por hora; os de todo o dia no topo), depois lembretes (atrasados primeiro).
    static func sortedForToday(_ items: [CalendarDayItem]) -> [CalendarDayItem] {
        items.sorted { lhs, rhs in
            if lhs.isReminder != rhs.isReminder { return !lhs.isReminder }
            if case .event(_, _, let lhsAllDay) = lhs.kind, case .event(_, _, let rhsAllDay) = rhs.kind, lhsAllDay != rhsAllDay {
                return lhsAllDay
            }
            if lhs.sortDate != rhs.sortDate { return lhs.sortDate < rhs.sortDate }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}
