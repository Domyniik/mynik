import SwiftData
import SwiftUI

/// Contas a pagar: por pagar (ordenadas por vencimento) e já pagas.
struct BillsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Bill> { !$0.isPaid }, sort: \Bill.dueDate)
    private var pendingBills: [Bill]

    @Query(filter: #Predicate<Bill> { $0.isPaid }, sort: \Bill.dueDate, order: .reverse)
    private var paidBills: [Bill]

    @State private var isAddingBill = false
    @State private var editingBill: Bill?

    var body: some View {
        List {
            Section("Por pagar") {
                if pendingBills.isEmpty {
                    Label("Tudo pago", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
                ForEach(pendingBills) { bill in
                    row(for: bill)
                }
            }

            if !paidBills.isEmpty {
                Section("Pagas") {
                    ForEach(paidBills) { bill in
                        row(for: bill)
                    }
                }
            }
        }
        .navigationTitle("Contas a pagar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Adicionar conta", systemImage: "plus") {
                    isAddingBill = true
                }
            }
        }
        .sheet(isPresented: $isAddingBill) {
            BillFormView()
        }
        .sheet(item: $editingBill) { bill in
            BillFormView(bill: bill)
        }
    }

    private func row(for bill: Bill) -> some View {
        Button {
            editingBill = bill
        } label: {
            BillRow(bill: bill, onPay: { pay(bill) })
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            if !bill.isPaid {
                Button("Paguei", systemImage: "checkmark") { pay(bill) }
                    .tint(.green)
            }
        }
        .swipeActions {
            Button("Apagar", systemImage: "trash", role: .destructive) { delete(bill) }
        }
        .contextMenu {
            if !bill.isPaid {
                Button("Paguei", systemImage: "checkmark") { pay(bill) }
            }
            Button("Editar", systemImage: "pencil") { editingBill = bill }
            Button("Apagar", systemImage: "trash", role: .destructive) { delete(bill) }
        }
    }

    private func pay(_ bill: Bill) {
        withAnimation {
            BillPaymentService.markPaid(bill, in: modelContext)
            try? modelContext.save()
        }
    }

    private func delete(_ bill: Bill) {
        modelContext.delete(bill)
        try? modelContext.save()
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        BillsView()
    }
}
