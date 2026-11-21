import Foundation
import SwiftData

/// Tipo de bloco de uma nota.
nonisolated enum NoteBlockKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    /// Título 1 (o valor "heading" vem das versões anteriores).
    case heading
    case heading2
    case heading3
    case bulleted
    case numbered
    case checklist
    case toggle
    case quote
    case callout
    case code
    case table
    case divider
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .text: "Texto"
        case .heading: "Título 1"
        case .heading2: "Título 2"
        case .heading3: "Título 3"
        case .bulleted: "Lista com marcas"
        case .numbered: "Lista numerada"
        case .checklist: "Lista de tarefas"
        case .toggle: "Alternar"
        case .quote: "Citação"
        case .callout: "Destaque"
        case .code: "Código"
        case .table: "Tabela"
        case .divider: "Divisor"
        case .image: "Imagem"
        }
    }

    var subtitle: String {
        switch self {
        case .text: "Parágrafo simples"
        case .heading: "Título grande de secção"
        case .heading2: "Título médio"
        case .heading3: "Título pequeno"
        case .bulleted: "Lista simples com marcas"
        case .numbered: "Lista com números"
        case .checklist: "Tarefas para marcar"
        case .toggle: "Texto que abre e fecha"
        case .quote: "Citação em destaque"
        case .callout: "Caixa com emoji"
        case .code: "Bloco de código"
        case .table: "Tabela simples"
        case .divider: "Linha de separação"
        case .image: "Foto ou imagem"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .heading: "textformat.size.larger"
        case .heading2: "textformat.size"
        case .heading3: "textformat.size.smaller"
        case .bulleted: "list.bullet"
        case .numbered: "list.number"
        case .checklist: "checklist"
        case .toggle: "chevron.right.circle"
        case .quote: "text.quote"
        case .callout: "lightbulb"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .table: "tablecells"
        case .divider: "minus"
        case .image: "photo"
        }
    }

    /// Palavras extra para o menu "/" (além do título).
    var searchTerms: [String] {
        switch self {
        case .text: ["paragrafo", "texto", "p"]
        case .heading: ["h1", "titulo"]
        case .heading2: ["h2", "titulo", "subtitulo"]
        case .heading3: ["h3", "titulo"]
        case .bulleted: ["ul", "marcas", "bullet", "lista"]
        case .numbered: ["ol", "numeros", "lista"]
        case .checklist: ["todo", "tarefa", "checkbox", "lista"]
        case .toggle: ["toggle", "expandir", "recolher"]
        case .quote: ["quote", "citacao"]
        case .callout: ["callout", "nota", "aviso", "emoji"]
        case .code: ["code", "codigo", "programar"]
        case .table: ["table", "grelha"]
        case .divider: ["hr", "linha", "separador", "divider"]
        case .image: ["foto", "imagem", "img"]
        }
    }

    /// Usa um único campo de texto (pode trocar de tipo sem perder o foco).
    var isTextual: Bool {
        switch self {
        case .image, .divider, .table: false
        default: true
        }
    }

    /// Return termina o bloco (em vez de inserir uma quebra de linha).
    var isSingleLine: Bool {
        switch self {
        case .heading, .heading2, .heading3, .bulleted, .numbered, .checklist, .toggle: true
        default: false
        }
    }

    /// Return cria um bloco do mesmo tipo (listas); um item vazio volta a texto.
    var continuesOnReturn: Bool {
        self == .bulleted || self == .numbered || self == .checklist
    }

    var isHeading: Bool {
        self == .heading || self == .heading2 || self == .heading3
    }

    /// Tipos que aparecem no menu "/" filtrados por `query` (sem acentos nem maiúsculas).
    static func matching(_ query: String) -> [NoteBlockKind] {
        let query = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return allCases }
        return allCases.filter { kind in
            let title = kind.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            return title.contains(query) || kind.searchTerms.contains { $0.hasPrefix(query) }
        }
    }
}

/// Bloco de uma nota: parágrafo, título, lista, citação, código, tabela, imagem…
@Model
final class NoteBlock {
    var uid: String = UUID().uuidString
    var kindRaw: String = NoteBlockKind.text.rawValue
    /// Texto do bloco (legenda, numa imagem; células separadas por tabulação e
    /// linhas por mudança de linha, numa tabela).
    var text: String = ""
    var isChecked: Bool = false
    /// JPEG já reduzido, guardado fora da base de dados.
    @Attribute(.externalStorage) var imageData: Data?
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    /// Emoji de um destaque.
    var emoji: String = "💡"
    /// Linguagem de um bloco de código.
    var language: String = ""
    /// Conteúdo escondido de um bloco "alternar".
    var detail: String = ""
    /// Um bloco "alternar" está aberto.
    var isExpanded: Bool = false

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
