import Foundation

/// Evita importar duas vezes o mesmo movimento (mesmo dia, valor e descrição).
nonisolated struct DuplicateDetector {
    private struct Key: Hashable {
        let day: Date
        let signedAmount: Decimal
        let title: String
    }

    private var keys: Set<Key> = []
    private let calendar: Calendar

    init(existing: [(date: Date, signedAmount: Decimal, title: String)], calendar: Calendar = .current) {
        self.calendar = calendar
        for item in existing {
            keys.insert(key(date: item.date, signedAmount: item.signedAmount, title: item.title))
        }
    }

    func isDuplicate(_ row: BankCSVImporter.Row) -> Bool {
        keys.contains(key(date: row.date, signedAmount: row.signedAmount, title: row.title))
    }

    private func key(date: Date, signedAmount: Decimal, title: String) -> Key {
        Key(
            day: calendar.startOfDay(for: date),
            signedAmount: signedAmount,
            title: BankCSVImporter.normalize(title)
        )
    }
}
