import SwiftUI

/// Paleta fixa de cores para categorias (guardada por nome no SwiftData).
nonisolated enum CategoryColor: String, Codable, CaseIterable, Sendable {
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }
}
