import SwiftUI

/// Linha de lista do sistema visual: ícone, título, subtítulo e valor à direita.
struct DSRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var symbolName: String?
    var color: Color?
    @ViewBuilder var trailing: Trailing
    @Environment(\.moduleTint) private var tint

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage symbolName: String? = nil,
        color: Color? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.color = color
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            if let symbolName {
                IconBadge(symbolName: symbolName, color: color ?? tint)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: DS.Spacing.s)
            trailing
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
