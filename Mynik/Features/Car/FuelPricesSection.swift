import SwiftUI

/// Os 3 postos mais baratos perto do utilizador, com a média da província.
struct FuelPricesSection: View {
    let fuelType: FuelType

    @AppStorage(SettingsKey.fuelProvinceID) private var provinceID = SpanishProvince.madrid.id
    @AppStorage(SettingsKey.fuelUsesLocation) private var usesLocation = false
    @State private var store = FuelPriceStore()
    @State private var location = LocationProvider()

    var body: some View {
        if fuelType.priceField != nil {
            Section {
                content
                NavigationLink("Ver todos os postos", value: fuelType)
            } header: {
                Text("\(fuelType.title) · \(SpanishProvince.named(id: provinceID).name)")
            } footer: {
                FuelPricesFooter(store: store, location: location, usesLocation: usesLocation)
            }
            .task(id: provinceID) { await store.load(provinceID: provinceID) }
            .task(id: usesLocation) {
                if usesLocation { await location.requestOnce() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = store.snapshot {
            let ranking = FuelPriceRanking.cheapest(snapshot.stations, fuel: fuelType, near: location.coordinate)
            ForEach(ranking.prefix(3)) { entry in
                FuelStationRow(entry: entry, unit: fuelType.unit)
            }
            if let average = FuelPriceRanking.average(snapshot.stations, fuel: fuelType) {
                LabeledContent("Média na província") {
                    Text(FuelStationRow.priceText(average, unit: fuelType.unit)).monospacedDigit()
                }
            }
            if !usesLocation {
                Button("Ordenar por perto de mim", systemImage: "location") { usesLocation = true }
            }
        } else if store.isLoading {
            HStack {
                ProgressView()
                Text("A carregar preços…").foregroundStyle(.secondary)
            }
        } else if let error = store.errorMessage {
            Label(error, systemImage: "wifi.slash").foregroundStyle(.secondary)
            Button("Tentar de novo") { Task { await store.load(provinceID: provinceID, force: true) } }
        }
    }
}

/// Origem e hora dos preços, avisos de rede e de localização.
struct FuelPricesFooter: View {
    let store: FuelPriceStore
    let location: LocationProvider
    let usesLocation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let snapshot = store.snapshot {
                let date = snapshot.publishedAt ?? snapshot.fetchedAt
                Text("Preços do Ministerio para la Transición Ecológica · \(date.formatted(.dateTime.day().month().hour().minute().locale(.app)))")
            }
            if let error = store.errorMessage, store.snapshot != nil {
                Text(error)
            }
            if usesLocation && location.isDenied {
                Text("Sem acesso à localização: ordenado só por preço. Podes permitir nos Ajustes.")
            } else if usesLocation && location.coordinate != nil {
                Text("Postos até 10 km de ti, do mais barato para o mais caro.")
            }
        }
    }
}

struct FuelStationRow: View {
    let entry: FuelPriceRanking.Entry
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.station.brand.isEmpty ? "Posto" : entry.station.brand)
                    .lineLimit(1)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Self.priceText(entry.price, unit: unit))
                .monospacedDigit()
                .fontWeight(.semibold)
            if let url = mapsURL {
                Link(destination: url) {
                    Image(systemName: "map")
                }
                .accessibilityLabel("Abrir no Mapas")
            }
        }
    }

    private var details: String {
        var parts = [entry.station.town, entry.station.address].filter { !$0.isEmpty }
        if let distance = entry.distance {
            parts.insert("\(distance.formatted(.number.precision(.fractionLength(1)).locale(.app))) km", at: 0)
        }
        return parts.joined(separator: " · ")
    }

    /// Abre o posto no Mapas (só as coordenadas públicas do posto).
    private var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(entry.station.latitude),\(entry.station.longitude)"),
            URLQueryItem(name: "q", value: entry.station.brand),
        ]
        return components?.url
    }

    static func priceText(_ price: Decimal, unit: String) -> String {
        "\(price.formatted(.number.precision(.fractionLength(3)).locale(.app))) €/\(unit)"
    }
}
