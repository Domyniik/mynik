import SwiftUI

extension FinanceRoute {
    /// Título curto para os atalhos em mosaico.
    var shortTitle: String {
        switch self {
        case .bills: "Contas"
        case .budget: "Orçamento"
        case .reports: "Relatórios"
        case .subscriptions: "Assinaturas"
        case .importCSV: "Importar"
        }
    }

    var tint: Color {
        switch self {
        case .bills: .orange
        case .budget: .blue
        case .reports: .purple
        case .subscriptions: .pink
        case .importCSV: .gray
        }
    }
}

/// Atalhos para os ecrãs de Finanças, em mosaicos.
struct FinanceShortcutGrid: View {
    @ScaledMetric(relativeTo: .body) private var minimumWidth: CGFloat = 100

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: DS.Spacing.s)], spacing: DS.Spacing.s) {
            ForEach(FinanceRoute.allCases) { route in
                NavigationLink(value: route) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        IconBadge(symbolName: route.symbolName, color: route.tint)
                        Text(route.shortTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.m)
                    .background(Color.dsSurface, in: .rect(cornerRadius: DS.Radius.tile))
                    .contentShape(.rect(cornerRadius: DS.Radius.tile))
                }
                .buttonStyle(.plain)
                // Dentro de uma `List` o mosaico não leva a seta de navegação.
                .navigationLinkIndicatorVisibility(.hidden)
                .accessibilityLabel(route.title)
            }
        }
    }
}
