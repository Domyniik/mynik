import Foundation
import Observation

/// Preços de combustível da província escolhida: mostra logo a cópia em cache
/// e atualiza da API quando tem mais de uma hora.
@MainActor
@Observable
final class FuelPriceStore {
    private(set) var snapshot: FuelPriceSnapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load(provinceID: String, force: Bool = false) async {
        if snapshot?.provinceID != provinceID {
            snapshot = FuelPriceCache.load(provinceID: provinceID)
        }
        if !force, let snapshot, Date.now.timeIntervalSince(snapshot.fetchedAt) < FuelPriceService.maximumAge {
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await FuelPriceService.fetch(provinceID: provinceID)
            FuelPriceCache.save(fresh)
            snapshot = fresh
            errorMessage = nil
        } catch {
            errorMessage = snapshot == nil
                ? "Não foi possível obter os preços. Verifica a ligação à internet."
                : "Sem ligação: a mostrar os últimos preços guardados."
        }
    }
}
