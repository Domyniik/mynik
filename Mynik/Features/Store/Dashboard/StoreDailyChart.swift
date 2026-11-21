import Charts
import SwiftUI

/// Vendas (barras) e lucro real (linha) de cada dia.
struct StoreDailyChart: View {
    let points: [StoreDailyPoint]

    /// Do lucro mais baixo (ou zero) às vendas mais altas, com folga.
    private var yDomain: ClosedRange<Double> {
        let low = min(0, points.map(\.profit.doubleValue).min() ?? 0)
        let high = max(1, points.map { max($0.sales, $0.profit).doubleValue }.max() ?? 1)
        return (low * 1.15)...(high * 1.1)
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Dia", point.date, unit: .day),
                    y: .value("Valor", point.sales)
                )
                .foregroundStyle(by: .value("Série", "Vendas"))
                .cornerRadius(3)
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Dia", point.date, unit: .day),
                    y: .value("Valor", point.profit)
                )
                .foregroundStyle(by: .value("Série", "Lucro"))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.secondary.opacity(0.4))
        }
        .chartForegroundStyleScale(["Vendas": AnyShapeStyle(AppSection.store.tint.gradient.opacity(0.75)), "Lucro": AnyShapeStyle(Color.green)])
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(.app))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount.formatted(.currency(code: Currency.defaultCode).precision(.fractionLength(0)).locale(.app)))
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 220)
        .accessibilityLabel("Vendas e lucro dos últimos \(points.count) dias")
    }
}
