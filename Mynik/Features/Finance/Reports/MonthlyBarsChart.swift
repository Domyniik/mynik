import Charts
import SwiftUI

/// Barras lado a lado de receitas e gastos por mês.
struct MonthlyBarsChart: View {
    let totals: [FinanceReport.MonthTotals]

    private struct Bar: Identifiable {
        let month: Date
        let kind: TransactionKind
        let amount: Decimal
        var id: String { "\(month.timeIntervalSince1970)-\(kind.rawValue)" }
    }

    private var bars: [Bar] {
        totals.flatMap {
            [
                Bar(month: $0.month, kind: .income, amount: $0.income),
                Bar(month: $0.month, kind: .expense, amount: $0.expenses),
            ]
        }
    }

    var body: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("Mês", bar.month, unit: .month),
                y: .value("Valor", bar.amount)
            )
            .position(by: .value("Tipo", bar.kind == .income ? "Receitas" : "Gastos"))
            .foregroundStyle(by: .value("Tipo", bar.kind == .income ? "Receitas" : "Gastos"))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale(["Receitas": Color.green, "Gastos": Color.red])
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(.app), centered: true)
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
    }
}
