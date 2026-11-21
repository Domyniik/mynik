import ActivityKit
import SwiftUI
import WidgetKit

/// Desenho da Live Activity das contas que vencem hoje.
struct BillDueLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BillDueActivityAttributes.self) { context in
            BillDueLockScreenView(state: context.state)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.hasOverdue ? "exclamationmark.circle.fill" : "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(context.state.hasOverdue ? .red : .orange)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.amountText)
                        .font(.title3.bold())
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(BillDueText.subtitle(context.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(context.state.hasOverdue ? .red : .orange)
                    .accessibilityLabel("Conta a vencer")
            } compactTrailing: {
                Text(context.state.amountText)
                    .monospacedDigit()
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Conta a vencer")
            }
        }
    }
}

private struct BillDueLockScreenView: View {
    let state: BillDueActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.hasOverdue ? "exclamationmark.circle.fill" : "calendar.badge.clock")
                .font(.largeTitle)
                .foregroundStyle(state.hasOverdue ? .red : .orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(BillDueText.subtitle(state))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.amountText)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private enum BillDueText {
    static func subtitle(_ state: BillDueActivityAttributes.ContentState) -> String {
        let base = state.hasOverdue ? "Em atraso" : "Vence hoje"
        return state.count > 1
            ? "\(base) · \(state.count) contas, \(state.totalText) no total"
            : "\(base) · abre o Mynik para marcar como paga"
    }
}
