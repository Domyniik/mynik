import SwiftData
import SwiftUI

/// Contas por pagar que vencem nos próximos `days` dias (inclui as atrasadas).
struct UpcomingBillsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bills: [Bill]
    @State private var paidCount = 0

    init(days: Int, now: Date = .now, calendar: Calendar = .current) {
        let startOfToday = calendar.startOfDay(for: now)
        let limit = calendar.date(byAdding: .day, value: days + 1, to: startOfToday) ?? startOfToday
        _bills = Query(
            filter: #Predicate<Bill> { !$0.isPaid && $0.dueDate < limit },
            sort: \Bill.dueDate
        )
    }

    var body: some View {
        DashboardCard("Contas a vencer", systemImage: "calendar.badge.clock") {
            if bills.count > 1 {
                Text(Currency.format(bills.reduce(Decimal.zero) { $0 + $1.amount }))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } content: {
            if bills.isEmpty {
                EmptyStateView("Tudo pago", message: "Nada a pagar nos próximos 7 dias.", systemImage: "checkmark.seal")
            } else {
                CardRows(bills) { bill in
                    BillRow(bill: bill, onPay: { pay(bill) })
                }
            }
        }
        .sensoryFeedback(.success, trigger: paidCount)
    }

    private func pay(_ bill: Bill) {
        withAnimation(.snappy) {
            BillPaymentService.markPaid(bill, in: modelContext)
            try? modelContext.save()
        }
        paidCount += 1
    }
}
