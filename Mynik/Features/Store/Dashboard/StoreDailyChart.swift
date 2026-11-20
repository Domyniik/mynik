import Charts
import SwiftUI

/// Vendas (barras) e lucro real (linha) de cada dia.
struct StoreDailyChart: View {
    let points: [StoreDailyPoint]

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Dia", point.date, unit: .day),
                    y: .value("Valor", point.sales)
                )
                .foregroundStyle(by: .value("Série", "Vendas"))
                .cornerRadius(2)
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Dia", point.date, unit: .day),
                    y: .value("Valor", point.profit)
                )
                .foregroundStyle(by: .value("Série", "Lucro"))
                .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.secondary.opacity(0.4))
        }
        .chartForegroundStyleScale(["Vendas": Color.accentColor.opacity(0.7), "Lucro": Color.green])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(.app))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
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
