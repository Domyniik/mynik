import Foundation
import SwiftData

/// Lança os gastos do carro na categoria "Carro" das Finanças e trata dos prazos.
enum CarExpenseService {
    static let categoryName = "Carro"

    /// Cria ou atualiza o movimento do abastecimento (ou retira-o, se `post` for `false`).
    static func sync(_ entry: FuelEntry, post: Bool, in context: ModelContext) {
        guard post else {
            LinkedTransactionService.remove(externalID: entry.transactionID, in: context)
            entry.transactionID = ""
            return
        }
        let id = entry.transactionID.isEmpty ? "car-fuel-\(entry.uid)" : entry.transactionID
        let vehicle = entry.vehicle?.displayName ?? "Carro"
        let posted = LinkedTransactionService.upsertExpense(
            externalID: id,
            title: entry.station.isEmpty ? "Combustível · \(vehicle)" : "Combustível · \(entry.station)",
            amount: entry.totalCost,
            currencyCode: entry.currencyCode,
            date: entry.date,
            categoryName: categoryName,
            notes: "Abastecimento de \(vehicle) aos \(entry.odometer.formatted(.number.locale(.app))) km.",
            in: context
        )
        entry.transactionID = posted == nil ? "" : id
    }

    static func sync(_ record: MaintenanceRecord, post: Bool, in context: ModelContext) {
        guard post else {
            LinkedTransactionService.remove(externalID: record.transactionID, in: context)
            record.transactionID = ""
            return
        }
        let id = record.transactionID.isEmpty ? "car-maintenance-\(record.uid)" : record.transactionID
        let vehicle = record.vehicle?.displayName ?? "Carro"
        let posted = LinkedTransactionService.upsertExpense(
            externalID: id,
            title: "\(record.displayTitle) · \(vehicle)",
            amount: record.cost,
            currencyCode: record.currencyCode,
            date: record.date,
            categoryName: categoryName,
            notes: record.workshop.isEmpty ? "" : "Oficina: \(record.workshop)",
            in: context
        )
        record.transactionID = posted == nil ? "" : id
    }

    /// Apaga o abastecimento e o movimento correspondente.
    static func delete(_ entry: FuelEntry, in context: ModelContext) {
        LinkedTransactionService.remove(externalID: entry.transactionID, in: context)
        entry.vehicle?.fuelEntries?.removeAll { $0 === entry }
        context.delete(entry)
    }

    static func delete(_ record: MaintenanceRecord, in context: ModelContext) {
        LinkedTransactionService.remove(externalID: record.transactionID, in: context)
        record.vehicle?.maintenanceRecords?.removeAll { $0 === record }
        context.delete(record)
    }

    /// Marca o prazo como feito: lança o valor pago e passa para o próximo vencimento.
    @discardableResult
    static func complete(
        _ deadline: CarDeadline,
        on date: Date = .now,
        amount: Decimal,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> FinanceTransaction? {
        let day = date.formatted(.iso8601.year().month().day())
        let vehicle = deadline.vehicle?.displayName ?? "Carro"
        let transaction = LinkedTransactionService.upsertExpense(
            externalID: "car-deadline-\(deadline.uid)-\(day)",
            title: "\(deadline.displayTitle) · \(vehicle)",
            amount: amount,
            currencyCode: deadline.currencyCode,
            date: date,
            categoryName: categoryName,
            in: context
        )
        deadline.lastDoneAt = date
        if amount > 0 { deadline.amount = amount }
        if let next = nextDueDate(for: deadline, completedOn: date, calendar: calendar) {
            deadline.dueDate = next
        }
        return transaction
    }

    /// Próximo vencimento depois de feito em `completedOn` (`nil` se não se repete).
    static func nextDueDate(for deadline: CarDeadline, completedOn: Date, calendar: Calendar = .current) -> Date? {
        guard deadline.renewalMonths > 0 else { return nil }
        if deadline.kind.renewsFromCompletion {
            return calendar.date(byAdding: .month, value: deadline.renewalMonths, to: completedOn)
        }
        // Renova no aniversário: avança até ficar depois do dia em que foi feito.
        var next = deadline.dueDate
        repeat {
            guard let date = calendar.date(byAdding: .month, value: deadline.renewalMonths, to: next) else { return nil }
            next = date
        } while next <= calendar.startOfDay(for: completedOn)
        return next
    }
}
