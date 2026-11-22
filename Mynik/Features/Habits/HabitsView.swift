import SwiftData
import SwiftUI

/// Hábitos: marcar o dia, sequência e objetivo semanal.
struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var isAdding = false
    @State private var editing: Habit?

    var body: some View {
        List {
            if habits.isEmpty {
                ContentUnavailableView {
                    Label("Sem hábitos", systemImage: "flame")
                } description: {
                    Text("Cria um hábito e marca-o todos os dias para construir uma sequência.")
                } actions: {
                    Button("Novo hábito") { isAdding = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                Section {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit)
                            .contextMenu {
                                Button("Editar", systemImage: "pencil") { editing = habit }
                                Button("Arquivar", systemImage: "archivebox") { archive(habit) }
                            }
                            .swipeActions {
                                Button("Arquivar", systemImage: "archivebox") { archive(habit) }
                                Button("Editar", systemImage: "pencil") { editing = habit }
                                    .tint(.blue)
                            }
                    }
                } footer: {
                    Text("Toca no círculo para marcar o dia de hoje.")
                }
            }
        }
        .navigationTitle("Hábitos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Novo hábito", systemImage: "plus") { isAdding = true }
            }
        }
        .sheet(isPresented: $isAdding) { HabitFormView(habit: nil, nextSortOrder: habits.count) }
        .sheet(item: $editing) { habit in HabitFormView(habit: habit, nextSortOrder: habits.count) }
    }

    private func archive(_ habit: Habit) {
        habit.isArchived = true
        try? modelContext.save()
    }
}

/// Linha de um hábito: botão do dia, sequência e últimos 7 dias.
struct HabitRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let habit: Habit

    var body: some View {
        let progress = HabitService.progress(of: habit)
        HStack(spacing: 12) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { HabitService.toggle(habit, in: modelContext) }
            } label: {
                Image(systemName: progress.isDoneToday ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(progress.isDoneToday ? habit.color.color : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(progress.isDoneToday ? "Desmarcar \(habit.name) hoje" : "Marcar \(habit.name) hoje")

            VStack(alignment: .leading, spacing: 4) {
                Label(habit.name, systemImage: habit.symbolName)
                    .font(.headline)
                Text(Self.subtitle(progress))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(Array(progress.lastSevenDays.enumerated()), id: \.offset) { _, done in
                    Circle()
                        .fill(done ? AnyShapeStyle(habit.color.color) : AnyShapeStyle(.quaternary))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(progress.lastSevenDays.filter { $0 }.count) dos últimos 7 dias cumpridos")
        }
        .padding(.vertical, 4)
    }

    static func subtitle(_ progress: HabitProgress) -> String {
        let streak = progress.streak == 1 ? "1 dia seguido" : "\(progress.streak) dias seguidos"
        return "\(streak) · \(progress.thisWeek)/\(progress.targetPerWeek) esta semana"
    }
}

/// Criar ou editar um hábito.
struct HabitFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let habit: Habit?
    let nextSortOrder: Int

    @State private var name = ""
    @State private var symbolName = "checkmark.circle"
    @State private var color = CategoryColor.green
    @State private var targetPerWeek = 7

    private static let symbols = [
        "checkmark.circle", "figure.run", "dumbbell", "book", "drop", "bed.double",
        "leaf", "brain.head.profile", "eurosign.circle", "laptopcomputer", "music.note", "fork.knife",
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome (ex.: Ginásio)", text: $name)
                Stepper(value: $targetPerWeek, in: 1...7) {
                    LabeledContent("Objetivo", value: targetPerWeek == 7 ? "todos os dias" : "\(targetPerWeek) dias por semana")
                }
                Section("Cor") {
                    ColorChoicePicker(selection: $color)
                }
                Section("Ícone") {
                    SymbolChoicePicker(symbols: Self.symbols, tint: color.color, selection: $symbolName)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(habit == nil ? "Novo hábito" : "Editar hábito")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let habit else { return }
                name = habit.name
                symbolName = habit.symbolName
                color = habit.color
                targetPerWeek = habit.targetPerWeek
            }
        }
    }

    private func save() {
        let target: Habit
        if let habit {
            target = habit
        } else {
            target = Habit(name: "")
            target.sortOrder = nextSortOrder
            modelContext.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.symbolName = symbolName
        target.colorName = color.rawValue
        target.targetPerWeek = targetPerWeek
        try? modelContext.save()
        dismiss()
    }
}

/// Hábitos do dia na tela Hoje.
struct TodayHabitsSection: View {
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.sortOrder) private var habits: [Habit]

    var body: some View {
        if !habits.isEmpty {
            let done = habits.filter { HabitService.progress(of: $0).isDoneToday }.count
            DashboardCard("Hábitos", systemImage: "flame") {
                Text("\(done) de \(habits.count)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
            } content: {
                CardRows(habits) { habit in
                    HabitRow(habit: habit)
                }
            }
            .sensoryFeedback(.success, trigger: done) { old, new in new > old }
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack { HabitsView() }
}
