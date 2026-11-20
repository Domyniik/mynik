import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct ProjectTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar(identifier: .gregorian)
    private let now: Date

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10)) ?? .now
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now) ?? now
    }

    @Test func progressCountsDoneTasks() throws {
        let project = Project(name: "Casa")
        context.insert(project)
        #expect(project.progress == 0)

        for (index, status) in [TaskStatus.done, .doing, .todo, .done].enumerated() {
            context.insert(ProjectTask(title: "T\(index)", status: status, project: project))
        }
        try context.save()

        #expect(project.progress == 0.5)
        #expect(project.openTaskCount == 2)
    }

    @Test func statusChangeTracksCompletionDate() {
        let task = ProjectTask(title: "Ligar ao banco")
        #expect(task.completedAt == nil)
        task.status = .done
        #expect(task.completedAt != nil)
        task.status = .doing
        #expect(task.completedAt == nil)
        #expect(TaskStatus.todo.next == .doing)
        #expect(TaskStatus.done.next == .todo)
    }

    @Test func columnsSortByPriorityThenDueDate() {
        let late = ProjectTask(title: "Sem prazo")
        let soon = ProjectTask(title: "Amanhã", dueDate: day(1))
        let urgent = ProjectTask(title: "Urgente", priority: .high, dueDate: day(5))
        let later = ProjectTask(title: "Daqui a 3 dias", dueDate: day(3))
        let doing = ProjectTask(title: "Em curso", status: .doing)

        let columns = TaskBoard.columns([late, soon, urgent, later, doing])
        #expect(columns[.todo]?.map(\.title) == ["Urgente", "Amanhã", "Daqui a 3 dias", "Sem prazo"])
        #expect(columns[.doing]?.map(\.title) == ["Em curso"])
        #expect(columns[.done]?.isEmpty == true)
    }

    @Test func todayShowsInProgressOverdueAndDueToday() {
        let tasks = [
            ProjectTask(title: "Em curso", status: .doing),
            ProjectTask(title: "Atrasada", dueDate: day(-2)),
            ProjectTask(title: "Hoje", dueDate: calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)),
            ProjectTask(title: "Amanhã", dueDate: day(1)),
            ProjectTask(title: "Sem prazo"),
            ProjectTask(title: "Feita atrasada", status: .done, dueDate: day(-1)),
        ]
        let titles = Set(TaskBoard.forToday(tasks, now: now, calendar: calendar).map(\.title))
        #expect(titles == ["Em curso", "Atrasada", "Hoje"])
        #expect(TaskBoard.isOverdue(tasks[1], now: now, calendar: calendar))
        #expect(!TaskBoard.isOverdue(tasks[2], now: now, calendar: calendar))
    }

    @Test func deletingProjectDeletesItsTasks() throws {
        let project = Project(name: "Viagem")
        context.insert(project)
        context.insert(ProjectTask(title: "Reservar voo", project: project))
        context.insert(ProjectTask(title: "Avulsa"))
        try context.save()

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<ProjectTask>())
        #expect(remaining.map(\.title) == ["Avulsa"])
    }

    @Test func draftRoundTrip() {
        let project = Project(name: "Loja")
        var draft = TaskDraft(project: project, status: .doing)
        draft.title = "  Fotos novas  "
        draft.hasDueDate = true
        draft.dueDate = day(2)
        draft.priority = .high
        let task = draft.makeTask()

        #expect(task.title == "Fotos novas")
        #expect(task.status == .doing)
        #expect(task.priority == .high)
        #expect(task.dueDate == day(2))
        #expect(task.project === project)
        #expect(TaskDraft(task).hasDueDate)
    }
}
