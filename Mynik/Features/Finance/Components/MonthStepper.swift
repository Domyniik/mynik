import SwiftUI

/// Escolha de mês com setas (anterior / seguinte).
struct MonthStepper: View {
    @Binding var month: Date
    var calendar: Calendar = .current

    private var title: String {
        let text = month.formatted(.dateTime.month(.wide).year().locale(.app))
        return text.prefix(1).uppercased(with: .app) + text.dropFirst()
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        HStack {
            Button("Mês anterior", systemImage: "chevron.left") { shift(-1) }
            Spacer()
            Text(title)
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            Button("Mês seguinte", systemImage: "chevron.right") { shift(1) }
                .disabled(isCurrentMonth)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func shift(_ value: Int) {
        withAnimation {
            month = calendar.date(byAdding: .month, value: value, to: month) ?? month
        }
    }
}
