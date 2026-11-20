import Foundation
import SwiftData

/// Prazo periódico do veículo.
nonisolated enum CarDeadlineKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case inspection
    case insurance
    case tax
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .inspection: "ITV (inspeção)"
        case .insurance: "Seguro"
        case .tax: "Imposto de circulação"
        case .other: "Outro"
        }
    }

    var symbolName: String {
        switch self {
        case .inspection: "checkmark.seal"
        case .insurance: "shield"
        case .tax: "building.columns"
        case .other: "calendar"
        }
    }

    /// A próxima ITV conta a partir do dia em que passou; o resto renova na data de vencimento.
    var renewsFromCompletion: Bool { self == .inspection }
}

/// ITV, seguro, imposto de circulação (IUC / IVTM) ou outro prazo que se repete.
@Model
final class CarDeadline {
    var uid: String = UUID().uuidString
    var kindRaw: String = CarDeadlineKind.inspection.rawValue
    var title: String = ""
    var dueDate: Date = Date.now
    /// Valor habitual a pagar (vai para as Finanças ao marcar como feito).
    var amount: Decimal = 0
    var currencyCode: String = Currency.defaultCode
    /// De quantos em quantos meses se repete (`0` = não se repete).
    var renewalMonths: Int = 12
    var notes: String = ""
    var lastDoneAt: Date?
    var createdAt: Date = Date.now

    var vehicle: Vehicle?

    var kind: CarDeadlineKind {
        get { CarDeadlineKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.title : trimmed
    }

    init(
        kind: CarDeadlineKind,
        title: String = "",
        dueDate: Date,
        amount: Decimal = 0,
        renewalMonths: Int = 12,
        vehicle: Vehicle? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.dueDate = dueDate
        self.amount = amount
        self.renewalMonths = renewalMonths
        self.vehicle = vehicle
    }
}
