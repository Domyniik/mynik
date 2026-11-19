import Charts
import SwiftUI

/// Donut com o peso de cada categoria nos gastos do mês.
struct CategoryDonutChart: View {
    let slices: [FinanceReport.CategorySlice]

    private var total: Decimal {
        slices.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Valor", slice.amount),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(slice.color.color)
            .accessibilityLabel(slice.name)
            .accessibilityValue(Currency.format(slice.amount))
        }
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let frame = proxy.plotFrame {
                    let rect = geometry[frame]
                    VStack(spacing: 2) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Currency.format(total))
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(height: 220)
    }
}
