import SwiftUI

/// Ícone redondo com a cor da categoria.
struct CategoryIcon: View {
    let category: Category?
    @ScaledMetric(relativeTo: .body) private var diameter = 34

    var body: some View {
        Image(systemName: category?.symbolName ?? "questionmark")
            .font(.callout)
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(category?.color.color ?? .gray, in: .circle)
            .accessibilityHidden(true)
    }
}
