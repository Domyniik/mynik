import SwiftData
import SwiftUI

/// ITV, seguro, imposto e outros prazos do veículo, com o botão "Feito".
struct CarDeadlinesSection: View {
    let vehicle: Vehicle
    @Binding var sheet: CarSheet?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Section {
            if vehicle.sortedDeadlines.isEmpty {
                Button("Adicionar ITV, seguro ou imposto", systemImage: "calendar.badge.plus") {
                    sheet = .deadline(vehicle, nil)
                }
            }
            ForEach(vehicle.sortedDeadlines) { deadline in
                Button { sheet = .deadline(vehicle, deadline) } label: {
                    CarDeadlineRow(deadline: deadline) { sheet = .complete(deadline) }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button("Feito", systemImage: "checkmark") { sheet = .complete(deadline) }
                        .tint(.green)
                }
                .swipeActions {
                    Button("Apagar", systemImage: "trash", role: .destructive) { delete(deadline) }
                }
                .contextMenu {
                    Button("Marcar como feito", systemImage: "checkmark") { sheet = .complete(deadline) }
                    Button("Apagar", systemImage: "trash", role: .destructive) { delete(deadline) }
                }
            }
        } header: {
            Text("Prazos")
        } footer: {
            if !vehicle.sortedDeadlines.isEmpty {
                Text("Recebes avisos 30 e 7 dias antes e no próprio dia. Ao marcar como feito, o valor vai para as Finanças (categoria Carro).")
            }
        }
    }

    private func delete(_ deadline: CarDeadline) {
        withAnimation {
            vehicle.deadlines?.removeAll { $0 === deadline }
            modelContext.delete(deadline)
            try? modelContext.save()
        }
    }
}

/// Linha de um prazo com o estado ("Vence em 12 dias") e o botão "Feito".
struct CarDeadlineRow: View {
    let deadline: CarDeadline
    var onComplete: () -> Void

    var body: some View {
        let isOverdue = DueDateText.isOverdue(deadline.dueDate)
        let days = DueDateText.daysUntil(deadline.dueDate)
        HStack(spacing: 12) {
            SymbolBadge(symbolName: deadline.kind.symbolName, color: isOverdue ? .red : days <= 30 ? .orange : .indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(deadline.displayTitle)
                Text("\(deadline.dueDate.formatted(.dateTime.day().month().year().locale(.app))) · \(DueDateText.describe(deadline.dueDate))")
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .secondary)
            }
            Spacer(minLength: 8)
            if deadline.amount > 0 {
                Text(Currency.format(deadline.amount, code: deadline.currencyCode))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if days <= 30 {
                Button("Feito", systemImage: "checkmark.circle", action: onComplete)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .buttonStyle(.borderless)
                    .tint(.green)
            }
        }
        .contentShape(.rect)
    }
}
