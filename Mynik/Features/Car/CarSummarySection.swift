import Charts
import SwiftUI

/// Quilómetros, consumo médio, custo por km e gasto do mês, com o gráfico do consumo.
struct CarSummarySection: View {
    let vehicle: Vehicle

    @Environment(\.currencyConverter) private var converter
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 150

    var body: some View {
        let economy = FuelEconomy(entries: vehicle.fuelEntries ?? [])
        let unit = "\(vehicle.fuelType.unit)/100 km"
        Section {
            VStack(spacing: DS.Spacing.s) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: DS.Spacing.s)], spacing: DS.Spacing.s) {
                    KPICard(
                        "Quilómetros",
                        value: "\(vehicle.currentOdometer.formatted(.number.locale(.app))) km",
                        systemImage: "road.lanes",
                        comparesPeriods: false
                    )
                    KPICard(
                        "Consumo médio",
                        value: economy.averagePer100km.map { "\(format($0)) \(unit)" } ?? "—",
                        systemImage: "fuelpump",
                        comparesPeriods: false
                    )
                    KPICard(
                        "Combustível/km",
                        value: economy.costPerKm.map {
                            $0.formatted(.currency(code: Currency.defaultCode).precision(.fractionLength(3)).locale(.app))
                        } ?? "—",
                        systemImage: "eurosign.circle",
                        comparesPeriods: false
                    )
                    KPICard("Gasto este mês", value: Currency.format(monthSpending), systemImage: "creditcard", comparesPeriods: false)
                }
                if economy.segments.count > 1 {
                    DashboardCard("Consumo", systemImage: "chart.xyaxis.line") {
                        if let last = economy.lastPer100km {
                            Text("Último: \(format(last)) \(unit)")
                                .foregroundStyle(.secondary)
                        }
                    } content: {
                        consumptionChart(economy.segments, unit: unit)
                    }
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .dsListCardRow()
        } footer: {
            if economy.segments.isEmpty {
                Text("O consumo aparece depois de dois abastecimentos com o depósito atestado.")
            }
        }
    }

    private func consumptionChart(_ segments: [FuelEconomy.Segment], unit: String) -> some View {
        Chart(segments, id: \.endDate) { segment in
            AreaMark(x: .value("Data", segment.endDate), y: .value(unit, segment.per100km))
                .interpolationMethod(.monotone)
                .foregroundStyle(.linearGradient(colors: [.indigo.opacity(0.3), .indigo.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Data", segment.endDate), y: .value(unit, segment.per100km))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(.indigo)
            PointMark(x: .value("Data", segment.endDate), y: .value(unit, segment.per100km))
                .foregroundStyle(.indigo)
        }
        .chartYScale(domain: .automatic(includesZero: false))
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
