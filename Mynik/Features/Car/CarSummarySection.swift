import Charts
import SwiftUI

/// Quilómetros, consumo médio, custo por km e gasto do mês, com o gráfico do consumo.
struct CarSummarySection: View {
    let vehicle: Vehicle

    @Environment(\.currencyConverter) private var converter

    var body: some View {
        let economy = FuelEconomy(entries: vehicle.fuelEntries ?? [])
        let unit = "\(vehicle.fuelType.unit)/100 km"
        Section {
            LabeledContent("Quilómetros") {
                Text("\(vehicle.currentOdometer.formatted(.number.locale(.app))) km").monospacedDigit()
            }
            LabeledContent("Consumo médio") {
                Text(economy.averagePer100km.map { "\(format($0)) \(unit)" } ?? "—").monospacedDigit()
            }
            if let last = economy.lastPer100km {
                LabeledContent("Último atesto") {
                    Text("\(format(last)) \(unit)").monospacedDigit()
                }
            }
            if let costPerKm = economy.costPerKm {
                LabeledContent("Combustível por km") {
                    Text(costPerKm, format: .currency(code: Currency.defaultCode).precision(.fractionLength(3)).locale(.app))
                        .monospacedDigit()
                }
            }
            LabeledContent("Gasto este mês") {
                Text(Currency.format(monthSpending)).monospacedDigit().fontWeight(.semibold)
            }
            if economy.segments.count > 1 {
                consumptionChart(economy.segments, unit: unit)
            }
        } footer: {
            if economy.segments.isEmpty {
                Text("O consumo aparece depois de dois abastecimentos com o depósito atestado.")
            }
        }
    }

    private func consumptionChart(_ segments: [FuelEconomy.Segment], unit: String) -> some View {
        Chart(segments, id: \.endDate) { segment in
            LineMark(x: .value("Data", segment.endDate), y: .value(unit, segment.per100km))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Data", segment.endDate), y: .value(unit, segment.per100km))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .foregroundStyle(.indigo)
        .frame(height: 140)
        .accessibilityLabel("Consumo em \(unit) por abastecimento")
    }

    /// Abastecimentos e manutenções deste mês, na moeda principal.
    private var monthSpending: Decimal {
        let calendar = Calendar.current
        let fuel = (vehicle.fuelEntries ?? [])
            .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + converter.convert($1.totalCost, from: $1.currencyCode) }
        let maintenance = (vehicle.maintenanceRecords ?? [])
            .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + converter.convert($1.cost, from: $1.currencyCode) }
        return fuel + maintenance
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(.app))
    }
}
