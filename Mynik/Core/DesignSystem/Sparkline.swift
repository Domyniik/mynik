import Charts
import SwiftUI

/// Mini gráfico de linha com área, sem eixos, para cartões de KPI.
struct Sparkline: View {
    let values: [Double]
    var color: Color?
    var height: CGFloat = 32
    @Environment(\.moduleTint) private var tint

    var body: some View {
        let color = color ?? tint
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            AreaMark(x: .value("Dia", index), y: .value("Valor", value))
                .foregroundStyle(.linearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Dia", index), y: .value("Valor", value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(width: height * 2.4, height: height)
        .accessibilityHidden(true)
    }
}

/// Mini gráfico de barras, sem eixos.
struct MiniBars: View {
    let values: [Double]
    var color: Color?
    var height: CGFloat = 32
    @Environment(\.moduleTint) private var tint

    var body: some View {
        let color = color ?? tint
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            BarMark(x: .value("Dia", index), y: .value("Valor", value))
                .foregroundStyle(color.gradient)
                .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: height * 2.4, height: height)
        .accessibilityHidden(true)
    }
}
