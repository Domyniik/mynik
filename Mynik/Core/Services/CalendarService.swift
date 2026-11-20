import EventKit
import Foundation
import Observation

/// Eventos do Calendário e lembretes do dia, para a tela Hoje.
///
/// Só pede acesso quando o utilizador toca em "Ligar"; atualiza sozinho
/// quando o Calendário ou os Lembretes mudam.
@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    enum Access: Equatable {
        case notDetermined
        case granted
        /// Recusado ou restrito: só se muda nos Ajustes.
        case denied
    }

    private(set) var eventsAccess: Access = .notDetermined
    private(set) var remindersAccess: Access = .notDetermined
    private(set) var items: [CalendarDayItem] = []

    private let store = EKEventStore()
    private var observer: (any NSObjectProtocol)?

    private init() {
        refreshAccess()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.reload() }
        }
    }

    var hasAnyAccess: Bool { eventsAccess == .granted || remindersAccess == .granted }
    var needsRequest: Bool { eventsAccess == .notDetermined || remindersAccess == .notDetermined }

    func requestAccess() async {
        if eventsAccess == .notDetermined {
            _ = try? await store.requestFullAccessToEvents()
        }
        if remindersAccess == .notDetermined {
            _ = try? await store.requestFullAccessToReminders()
        }
        refreshAccess()
        await reload()
    }

    func reload(now: Date = .now, calendar: Calendar = .current) async {
        refreshAccess()
        var result: [CalendarDayItem] = []
        if eventsAccess == .granted {
            result += todayEvents(now: now, calendar: calendar)
        }
        if remindersAccess == .granted {
            result += await openReminders(dueBy: now, calendar: calendar)
        }
        items = CalendarDayItem.sortedForToday(result)
    }

    /// Marca um lembrete como feito (ou volta a abri-lo).
    func complete(_ item: CalendarDayItem) async {
        guard item.isReminder, let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
        await reload()
    }

    // MARK: - Privado

    private func refreshAccess() {
        eventsAccess = Self.access(for: EKEventStore.authorizationStatus(for: .event))
        remindersAccess = Self.access(for: EKEventStore.authorizationStatus(for: .reminder))
    }

    private static func access(for status: EKAuthorizationStatus) -> Access {
        switch status {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private func todayEvents(now: Date, calendar: Calendar) -> [CalendarDayItem] {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarDayItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Sem título",
                kind: .event(start: event.startDate, end: event.endDate, isAllDay: event.isAllDay),
                color: Self.components(of: event.calendar.cgColor),
                location: event.location ?? ""
            )
        }
    }

    /// Lembretes por fazer que vencem até ao fim de hoje (inclui atrasados).
    private func openReminders(dueBy now: Date, calendar: Calendar) async -> [CalendarDayItem] {
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: endOfToday, calendars: nil)
        let store = store
        // O EventKit devolve os lembretes noutra fila: convertem-se logo em valores.
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).map { reminder in
                    let components = reminder.dueDateComponents
                    let due = components.flatMap { Calendar.current.date(from: $0) }
                    return CalendarDayItem(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Sem título",
                        kind: .reminder(due: due, hasTime: components?.hour != nil),
                        color: Self.components(of: reminder.calendar?.cgColor)
                    )
                }
                continuation.resume(returning: items)
            }
        }
    }

    nonisolated private static func components(of color: CGColor?) -> [Double] {
        guard let color, let rgb = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let parts = rgb.components, parts.count >= 3 else { return [] }
        return parts.prefix(3).map(Double.init)
    }
}
