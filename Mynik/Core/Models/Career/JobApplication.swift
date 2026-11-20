import Foundation
import SwiftData

/// Estado de uma candidatura.
nonisolated enum ApplicationStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case applied
    case interviewing
    case offer
    case accepted
    case rejected
    case noResponse

    var id: Self { self }

    var title: String {
        switch self {
        case .applied: "Enviada"
        case .interviewing: "Entrevistas"
        case .offer: "Proposta"
        case .accepted: "Aceite"
        case .rejected: "Recusada"
        case .noResponse: "Sem resposta"
        }
    }

    var symbolName: String {
        switch self {
        case .applied: "paperplane"
        case .interviewing: "person.2"
        case .offer: "envelope.open"
        case .accepted: "checkmark.seal"
        case .rejected: "xmark.circle"
        case .noResponse: "moon.zzz"
        }
    }

    /// Ainda à espera de algo (conta para os follow-ups).
    var isActive: Bool { self == .applied || self == .interviewing || self == .offer }

    /// A empresa respondeu (para a taxa de resposta).
    var gotResponse: Bool { self != .applied && self != .noResponse }
}

/// Candidatura a um emprego, com o próximo follow-up.
@Model
final class JobApplication {
    var uid: String = UUID().uuidString
    var company: String = ""
    var role: String = ""
    var appliedAt: Date = Date.now
    var statusRaw: String = ApplicationStatus.applied.rawValue
    var statusChangedAt: Date = Date.now
    /// Quando voltar a contactar a empresa (`nil` = sem follow-up).
    var followUpDate: Date?
    var location: String = ""
    var link: String = ""
    var salary: String = ""
    var contact: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now

    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRaw) ?? .applied }
        set {
            guard newValue != status else { return }
            statusRaw = newValue.rawValue
            statusChangedAt = .now
            if !newValue.isActive { followUpDate = nil }
        }
    }

    var url: URL? {
        let trimmed = link.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    }

    init(company: String, role: String, appliedAt: Date = .now, status: ApplicationStatus = .applied, followUpDate: Date? = nil) {
        self.company = company
        self.role = role
        self.appliedAt = appliedAt
        self.statusRaw = status.rawValue
        self.followUpDate = followUpDate
    }
}

/// Estado de um curso ou certificação.
nonisolated enum CourseStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case planned
    case inProgress
    case completed

    var id: Self { self }

    var title: String {
        switch self {
        case .planned: "Por começar"
        case .inProgress: "Em curso"
        case .completed: "Concluídos"
        }
    }

    var symbolName: String {
        switch self {
        case .planned: "bookmark"
        case .inProgress: "book"
        case .completed: "graduationcap"
        }
    }
}

/// Curso ou certificação, com progresso e validade do certificado.
@Model
final class Course {
    var uid: String = UUID().uuidString
    var title: String = ""
    var provider: String = ""
    var statusRaw: String = CourseStatus.planned.rawValue
    /// Progresso de 0 a 1.
    var progress: Double = 0
    var completedAt: Date?
    var link: String = ""
    var credentialID: String = ""
    /// Validade do certificado (algumas certificações expiram).
    var expiresAt: Date?
    var notes: String = ""
    var createdAt: Date = Date.now

    var status: CourseStatus {
        get { CourseStatus(rawValue: statusRaw) ?? .planned }
        set {
            statusRaw = newValue.rawValue
            if newValue == .completed {
                progress = 1
                completedAt = completedAt ?? .now
            } else {
                completedAt = nil
            }
        }
    }

    var url: URL? {
        let trimmed = link.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    }

    init(title: String, provider: String = "", status: CourseStatus = .planned) {
        self.title = title
        self.provider = provider
        self.statusRaw = status.rawValue
        if status == .completed {
            progress = 1
            completedAt = .now
        }
    }
}
