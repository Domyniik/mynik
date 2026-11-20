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
                        .buttonStyle(.borderedProminent)
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
    let habit: Habit

    var body: some View {
        let progress = HabitService.progress(of: habit)
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { HabitService.toggle(habit, in: modelContext) }
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
                Picker("Ícone", selection: $symbolName) {
                    ForEach(Self.symbols, id: \.self) { symbol in
                        Image(systemName: symbol).tag(symbol)
                    }
                }
                Picker("Cor", selection: $color) {
                    ForEach(CategoryColor.allCases, id: \.self) { color in
                        Image(systemName: "circle.fill")
                            .foregroundStyle(color.color)
                            .accessibilityLabel(color.rawValue)
                            .tag(color)
                    }
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
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
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
            Section("Hábitos") {
                ForEach(habits) { habit in
                    HabitRow(habit: habit)
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack { HabitsView() }
}
