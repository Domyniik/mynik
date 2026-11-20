import SwiftUI

/// Linha de um movimento numa lista.
struct TransactionRow: View {
    let transaction: FinanceTransaction

    @Environment(\.currencyConverter) private var converter

    private var formattedAmount: String {
        let value = Currency.format(transaction.amount, code: transaction.currencyCode)
        return transaction.kind == .income ? "+\(value)" : "−\(value)"
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: transaction.category)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.title)
                        .lineLimit(1)
                    if transaction.isAutomatic {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Atualizado automaticamente")
                    }
                }

                Text("\(transaction.category?.name ?? "Sem categoria") · \(transaction.date.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .monospacedDigit()
                    .foregroundStyle(transaction.kind == .income ? .green : .primary)

                if transaction.currencyCode != Currency.defaultCode {
                    Text("≈ \(Currency.format(converter.amountInDefaultCurrency(transaction)))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
