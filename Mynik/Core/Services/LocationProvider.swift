import CoreLocation
import Observation

/// Localização aproximada, pedida uma vez para ordenar os postos de combustível
/// por distância. Nunca sai do dispositivo.
@MainActor
@Observable
final class LocationProvider {
    private(set) var coordinate: FuelPriceRanking.Coordinate?
    private(set) var isDenied = false
    private(set) var isLocating = false

    /// Pede autorização (texto em `NSLocationWhenInUseUsageDescription`) e lê a posição atual.
    func requestOnce() async {
        guard coordinate == nil, !isLocating else { return }
        isLocating = true
        defer { isLocating = false }

        #if os(iOS)
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        #endif
        // No Mac, as atualizações pedem a autorização sozinhas.
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    isDenied = true
                    break
                }
                if let location = update.location {
                    coordinate = .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                    isDenied = false
                    break
                }
            }
        } catch {
            // Sem localização: os postos ficam ordenados só por preço.
        }
    }
}
