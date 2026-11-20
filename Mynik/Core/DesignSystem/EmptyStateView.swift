import SwiftUI

/// Estado vazio compacto para dentro de cartões e secções (o `ContentUnavailableView` fica para ecrãs inteiros).
struct EmptyStateView<Actions: View>: View {
    let title: String
    let message: String?
    let symbolName: String
    @ViewBuilder var actions: Actions
    @Environment(\.moduleTint) private var tint

    init(_ title: String, message: String? = nil, systemImage symbolName: String, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.message = message
        self.symbolName = symbolName
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Image(systemName: symbolName)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                actions
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}
