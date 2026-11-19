import SwiftUI

/// Ícone redondo com a cor da categoria.
struct CategoryIcon: View {
    let category: Category?

    var body: some View {
        Image(systemName: category?.symbolName ?? "questionmark")
            .font(.callout)
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(category?.color.color ?? .gray, in: .circle)
            .accessibilityHidden(true)
    }
}
