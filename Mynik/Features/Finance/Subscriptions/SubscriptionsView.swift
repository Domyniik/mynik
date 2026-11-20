import SwiftData
import SwiftUI

/// Assinaturas ativas, com o custo total por mês e por ano.
struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter

    @Query(filter: #Predicate<Bill> { $0.isSubscription }, sort: \Bill.title)
    private var subscriptions: [Bill]

    @State private var isAdding = false
    @State private var editing: Bill?

    var body: some View {
        let summary = SubscriptionSummary(bills: subscriptions, converter: converter)

        List {
            if !subscriptions.isEmpty {
                Section {
                    SubscriptionTotalsCard(summary: summary, count: subscriptions.count)
                }
            }

            Section {
                ForEach(subscriptions) { bill in
                    Button {
                        editing = bill
                    } label: {
                        SubscriptionRow(bill: bill, monthlyCost: SubscriptionSummary.monthlyCost(of: bill, converter: converter))
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Apagar", systemImage: "trash", role: .destructive) { delete(bill) }
                    }
                    .contextMenu {
                        Button("Editar", systemImage: "pencil") { editing = bill }
                        Button("Apagar", systemImage: "trash", role: .destructive) { delete(bill) }
                    }
                }
            }
        }
        .overlay {
            if subscriptions.isEmpty {
                ContentUnavailableView {
                    Label("Sem assinaturas", systemImage: "repeat.circle")
                } description: {
                    Text("Regista Spotify, ginásio, iCloud... e vê quanto gastas por ano.")
                } actions: {
                    Button("Adicionar assinatura") { isAdding = true }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .navigationTitle("Assinaturas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Adicionar assinatura", systemImage: "plus") { isAdding = true }
            }
        }
        .sheet(isPresented: $isAdding) {
            BillFormView(isSubscription: true)
        }
        .sheet(item: $editing) { bill in
            BillFormView(bill: bill)
        }
    }

    private func delete(_ bill: Bill) {
        modelContext.delete(bill)
        try? modelContext.save()
    }
}

private struct SubscriptionTotalsCard: View {
    let summary: SubscriptionSummary
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Por mês")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Currency.format(summary.monthlyTotal))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
            }

            HStack {
                Label {
                    Text("\(Currency.format(summary.yearlyTotal)) por ano")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(count == 1 ? "1 assinatura" : "\(count) assinaturas")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SubscriptionRow: View {
    let bill: Bill
    let monthlyCost: Decimal

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: bill.category)

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.title)
                    .lineLimit(1)
                Text("\(bill.recurrence.title) · próximo \(bill.dueDate.formatted(.dateTime.day().month(.abbreviated).locale(.app)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Currency.format(bill.amount, code: bill.currencyCode))
                    .monospacedDigit()
                if bill.recurrence != .monthly || bill.currencyCode != Currency.defaultCode {
                    Text("\(Currency.format(monthlyCost))/mês")
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

#Preview(traits: .sampleData) {
    NavigationStack {
        SubscriptionsView()
    }
}
