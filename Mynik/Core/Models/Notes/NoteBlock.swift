import Foundation
import SwiftData

/// Tipo de bloco de uma nota.
nonisolated enum NoteBlockKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case heading
    case checklist
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .text: "Texto"
        case .heading: "Título"
        case .checklist: "Lista de tarefas"
        case .image: "Imagem"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .heading: "textformat.size"
        case .checklist: "checklist"
        case .image: "photo"
        }
    }

    /// Pode ser convertido noutro tipo de texto (as imagens não).
    var isTextual: Bool { self != .image }
}

/// Bloco de uma nota: parágrafo, título, item de checklist ou imagem.
@Model
final class NoteBlock {
    var uid: String = UUID().uuidString
    var kindRaw: String = NoteBlockKind.text.rawValue
    /// Texto do bloco (legenda, no caso de uma imagem).
    var text: String = ""
    var isChecked: Bool = false
    /// JPEG já reduzido, guardado fora da base de dados.
    @Attribute(.externalStorage) var imageData: Data?
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    var note: Note?

    var kind: NoteBlockKind {
        get { NoteBlockKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: NoteBlockKind, text: String = "", isChecked: Bool = false, imageData: Data? = nil, sortOrder: Int = 0) {
        self.kindRaw = kind.rawValue
        self.text = text
        self.isChecked = isChecked
        self.imageData = imageData
        self.sortOrder = sortOrder
    }
}
