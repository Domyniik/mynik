import SwiftUI

/// Cabeçalho de secção: ícone com a cor do módulo, título e acessório opcional.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var symbolName: String?
    @ViewBuilder var accessory: Accessory
    @Environment(\.moduleTint) private var tint

    init(_ title: String, systemImage symbolName: String? = nil, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.symbolName = symbolName
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
            if let symbolName {
                Image(systemName: symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DS.Spacing.s)
            accessory
                .font(.subheadline)
        }
    }
}

/// Cabeçalho de secção de uma `List` (Definições, formulários): ícone em quadrado colorido e título.
struct ListSectionHeader: View {
    let title: String
    let symbolName: String
    let color: Color

    init(_ title: String, systemImage symbolName: String, color: Color) {
        self.title = title
        self.symbolName = symbolName
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        } icon: {
            IconBadge(symbolName: symbolName, color: color)
                .scaleEffect(0.8)
        }
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }
}
