import Foundation

/// Números da procura de emprego: ativas, entrevistas e taxa de resposta.
nonisolated struct CareerStats: Equatable, Sendable {
    var total = 0
    var active = 0
    var interviews = 0
    var offers = 0
    var responded = 0

    /// Fração de candidaturas com resposta (`nil` sem candidaturas).
    var responseRate: Double? {
        total > 0 ? Double(responded) / Double(total) : nil
    }

    init(statuses: [ApplicationStatus]) {
        total = statuses.count
        active = statuses.count(where: \.isActive)
        interviews = statuses.count { $0 == .interviewing }
        offers = statuses.count { $0 == .offer || $0 == .accepted }
        responded = statuses.count(where: \.gotResponse)
    }

    /// Data do follow-up sugerido (uma semana depois).
    static func suggestedFollowUp(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 7, to: date) ?? date
    }
}
