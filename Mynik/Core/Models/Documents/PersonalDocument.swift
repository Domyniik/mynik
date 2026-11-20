import Foundation
import SwiftData

/// Tipo de documento.
nonisolated enum DocumentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case idCard
    case passport
    case residence
    case drivingLicense
    case healthCard
    case insurance
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .idCard: "Cartão de cidadão / RG"
        case .passport: "Passaporte"
        case .residence: "Residência (TIE / NIE)"
        case .drivingLicense: "Carta de condução"
        case .healthCard: "Cartão de saúde"
        case .insurance: "Seguro"
        case .other: "Outro"
        }
    }

    var symbolName: String {
        switch self {
        case .idCard: "person.text.rectangle"
        case .passport: "book.closed"
        case .residence: "house.and.flag"
        case .drivingLicense: "car.rear"
        case .healthCard: "cross.case"
        case .insurance: "shield.lefthalf.filled"
        case .other: "doc.text"
        }
    }
}

/// Documento pessoal com validade, número e fotos (protegidos por Face ID).
@Model
final class PersonalDocument {
    var uid: String = UUID().uuidString
    var title: String = ""
    var kindRaw: String = DocumentKind.idCard.rawValue
    var number: String = ""
    /// Quem emitiu (país, entidade...).
    var issuer: String = ""
    var expiryDate: Date?
    /// Avisar a partir de quantos dias antes de expirar.
    var remindDaysBefore: Int = 60
    var notes: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \DocumentPhoto.document)
    var photos: [DocumentPhoto]? = []

    var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.title : trimmed
    }

    var sortedPhotos: [DocumentPhoto] {
        (photos ?? []).sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    init(kind: DocumentKind, title: String = "", number: String = "", expiryDate: Date? = nil) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.number = number
        self.expiryDate = expiryDate
    }
}

/// Foto de um documento (frente, verso...), guardada fora da base de dados.
@Model
final class DocumentPhoto {
    var uid: String = UUID().uuidString
    /// JPEG já reduzido.
    @Attribute(.externalStorage) var imageData: Data?
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    var document: PersonalDocument?

    init(imageData: Data, sortOrder: Int = 0) {
        self.imageData = imageData
        self.sortOrder = sortOrder
    }
}
