import Foundation

/// Capa de uma página: gradientes predefinidos (guardados por nome em `Note.coverRaw`).
nonisolated enum NoteCover: String, CaseIterable, Identifiable, Sendable {
    case sunset, ocean, forest, lavender, peach, graphite, sand, aurora

    var id: Self { self }

    var title: String {
        switch self {
        case .sunset: "Pôr do sol"
        case .ocean: "Oceano"
        case .forest: "Floresta"
        case .lavender: "Lavanda"
        case .peach: "Pêssego"
        case .graphite: "Grafite"
        case .sand: "Areia"
        case .aurora: "Aurora"
        }
    }

    /// Cores do gradiente (RGB 0–1), da esquerda para a direita.
    var colors: [(red: Double, green: Double, blue: Double)] {
        switch self {
        case .sunset: [(0.98, 0.55, 0.36), (0.91, 0.30, 0.47)]
        case .ocean: [(0.20, 0.55, 0.85), (0.13, 0.78, 0.76)]
        case .forest: [(0.20, 0.55, 0.36), (0.55, 0.76, 0.40)]
        case .lavender: [(0.62, 0.53, 0.92), (0.86, 0.62, 0.90)]
        case .peach: [(1.00, 0.80, 0.62), (0.98, 0.62, 0.58)]
        case .graphite: [(0.25, 0.27, 0.31), (0.47, 0.50, 0.55)]
        case .sand: [(0.93, 0.85, 0.70), (0.80, 0.68, 0.52)]
        case .aurora: [(0.15, 0.25, 0.55), (0.25, 0.75, 0.65), (0.70, 0.90, 0.55)]
        }
    }
}

extension Note {
    var cover: NoteCover? {
        get { NoteCover(rawValue: coverRaw) }
        set { coverRaw = newValue?.rawValue ?? "" }
    }
}
