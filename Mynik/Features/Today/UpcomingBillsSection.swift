import SwiftData
import SwiftUI

/// Contas por pagar que vencem nos próximos `days` dias (inclui as atrasadas).
struct UpcomingBillsSection: View {
    @Query private var bills: [Bill]

    init(days: Int, now: Date = .now, calendar: Calendar = .current) {
        let startOfToday = calendar.startOfDay(for: now)
        let limit = calendar.date(byAdding: .day, value: days + 1, to: startOfToday) ?? startOfToday
        _bills = Query(
            filter: #Predicate<Bill> { !$0.isPaid && $0.dueDate < limit },
            sort: \Bill.dueDate
        )
    }

    var body: some View {
        Section("Contas a vencer") {
            if bills.isEmpty {
                Label("Nada a pagar nos próximos 7 dias", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bills) { bill in
                    BillRow(bill: bill)
                }
            }
        }
    }
}

private struct BillRow: View {
    let bill: Bill

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: bill.category)

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.title)
                    .lineLimit(1)
                Text(DueDateText.describe(bill.dueDate))
                    .font(.caption)
                    .foregroundStyle(DueDateText.isOverdue(bill.dueDate) ? .red : .secondary)
            }

            Spacer(minLength: 8)

            Text(Currency.format(bill.amount, code: bill.currencyCode))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
