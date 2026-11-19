import Foundation

/// Movimentos agrupados por mês, do mais recente para o mais antigo.
struct TransactionMonthGroup: Identifiable {
    let month: Date
    let transactions: [FinanceTransaction]

    var id: Date { month }

    var title: String {
        month.formatted(.dateTime.month(.wide).year().locale(.app)).capitalized(with: .app)
    }

    static func group(
        _ transactions: [FinanceTransaction],
        calendar: Calendar = .current
    ) -> [TransactionMonthGroup] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.dateInterval(of: .month, for: transaction.date)?.start ?? transaction.date
        }

        return grouped
            .map { month, items in
                TransactionMonthGroup(month: month, transactions: items.sorted { $0.date > $1.date })
            }
            .sorted { $0.month > $1.month }
    }
}
