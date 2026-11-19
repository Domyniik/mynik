import SwiftUI

/// Linha de um movimento numa lista.
struct TransactionRow: View {
    let transaction: FinanceTransaction

    private var formattedAmount: String {
        let value = Currency.format(transaction.amount, code: transaction.currencyCode)
        return transaction.kind == .income ? "+\(value)" : "−\(value)"
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: transaction.category)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .lineLimit(1)

                Text("\(transaction.category?.name ?? "Sem categoria") · \(transaction.date.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(formattedAmount)
                .monospacedDigit()
                .foregroundStyle(transaction.kind == .income ? .green : .primary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
