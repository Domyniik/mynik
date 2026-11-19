import Foundation

nonisolated enum BillRecurrence: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case weekly
    case monthly
    case yearly

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "Única"
        case .weekly: "Semanal"
        case .monthly: "Mensal"
        case .yearly: "Anual"
        }
    }

    /// Valor mensal equivalente de um pagamento de `amount` (`nil` se não se repete).
    /// Multiplica antes de dividir para não perder precisão em `Decimal`.
    func monthlyAmount(for amount: Decimal) -> Decimal? {
        switch self {
        case .none: nil
        case .weekly: amount * 52 / 12
        case .monthly: amount
        case .yearly: amount / 12
        }
    }

    /// Próxima data de vencimento depois de `date`, ou `nil` se não se repete.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none: nil
        case .weekly: calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly: calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}
