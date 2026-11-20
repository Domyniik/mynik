import Foundation
import SwiftData

/// Abastecimento (ou carregamento, num elétrico).
@Model
final class FuelEntry {
    var uid: String = UUID().uuidString
    var date: Date = Date.now
    /// Conta-quilómetros no momento do abastecimento.
    var odometer: Int = 0
    /// Litros (ou kWh) abastecidos.
    var quantity: Double = 0
    var totalCost: Decimal = 0
    var currencyCode: String = Currency.defaultCode
    /// Depósito atestado: necessário para calcular o consumo.
    var isFullTank: Bool = true
    var station: String = ""
    var notes: String = ""
    /// `externalID` do movimento nas Finanças; vazio se não foi lançado.
    var transactionID: String = ""
    var createdAt: Date = Date.now

    var vehicle: Vehicle?

    /// Preço por litro (ou kWh).
    var unitPrice: Decimal? {
        quantity > 0 ? totalCost / Decimal(quantity) : nil
    }

    init(
        date: Date = .now,
        odometer: Int,
        quantity: Double,
        totalCost: Decimal,
        isFullTank: Bool = true,
        station: String = "",
        vehicle: Vehicle? = nil
    ) {
        self.date = date
        self.odometer = odometer
        self.quantity = quantity
        self.totalCost = totalCost
        self.isFullTank = isFullTank
        self.station = station
        self.vehicle = vehicle
    }
}
