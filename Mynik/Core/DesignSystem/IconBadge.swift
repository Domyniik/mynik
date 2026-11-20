import SwiftUI

/// Ícone num quadrado arredondado com gradiente (como nos Ajustes do sistema).
struct IconBadge: View {
    let symbolName: String
    let color: Color
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: DS.Radius.badge * size / 30))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(AppSection.allCases) { IconBadge(symbolName: $0.symbolName, color: $0.tint) }
    }
    .padding()
}
