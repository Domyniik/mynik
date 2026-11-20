import SwiftUI

/// Todos os postos da província para um combustível, com pesquisa e escolha da província.
struct FuelPricesView: View {
    @State var fuelType: FuelType

    @AppStorage(SettingsKey.fuelProvinceID) private var provinceID = SpanishProvince.madrid.id
    @AppStorage(SettingsKey.fuelUsesLocation) private var usesLocation = false
    @State private var store = FuelPriceStore()
    @State private var location = LocationProvider()
    @State private var search = ""

    var body: some View {
        List {
            Section {
                Picker("Província", selection: $provinceID) {
                    ForEach(SpanishProvince.all) { Text($0.name).tag($0.id) }
                }
                Picker("Combustível", selection: $fuelType) {
                    ForEach(FuelType.allCases.filter { $0.priceField != nil }) { Text($0.title).tag($0) }
                }
                Toggle("Perto de mim (10 km)", isOn: $usesLocation)
            } footer: {
                FuelPricesFooter(store: store, location: location, usesLocation: usesLocation)
            }

            Section("\(stations.count) postos") {
                ForEach(stations) { entry in
                    FuelStationRow(entry: entry, unit: fuelType.unit)
                }
            }
        }
        .navigationTitle("Preços de combustível")
        .searchable(text: $search, prompt: "Marca ou localidade")
        .refreshable { await store.load(provinceID: provinceID, force: true) }
        .overlay {
            if store.snapshot == nil, store.isLoading {
                ProgressView("A carregar preços…")
            }
        }
        .task(id: provinceID) { await store.load(provinceID: provinceID) }
        .task(id: usesLocation) {
            if usesLocation { await location.requestOnce() }
        }
    }

    private var stations: [FuelPriceRanking.Entry] {
        guard let snapshot = store.snapshot else { return [] }
        let all = FuelPriceRanking.cheapest(snapshot.stations, fuel: fuelType, near: usesLocation ? location.coordinate : nil)
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.station.brand.localizedStandardContains(query)
                || $0.station.town.localizedStandardContains(query)
                || $0.station.address.localizedStandardContains(query)
        }
    }
}
