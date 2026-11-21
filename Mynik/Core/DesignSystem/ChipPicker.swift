import SwiftUI

/// Seletor em cápsulas de vidro, com a seleção a deslizar entre opções (`matchedGeometryEffect`).
///
/// Com Reduzir movimento, a seleção muda sem animação (ver `RootView`).
struct ChipPicker<Value: Hashable & Identifiable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(options) { option in
                    let isSelected = option == selection
                    Button {
                        withAnimation(.snappy) { selection = option }
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.horizontal, DS.Spacing.m)
                            .padding(.vertical, DS.Spacing.s - 1)
                            .frame(maxWidth: .infinity)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(Color.brandGradientBottom)
                                        .matchedGeometryEffect(id: "selection", in: namespace)
                                }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(DS.Spacing.xs)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(maxWidth: 480)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
