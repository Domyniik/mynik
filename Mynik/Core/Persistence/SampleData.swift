import SwiftData
import SwiftUI

/// Dados de exemplo para as previews do Xcode e para o modo de demonstração
/// (`-MynikDemo`, usado nas screenshots sem tocar nos dados reais).
struct SampleData: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try DefaultDataSeeder.seedIfNeeded(in: context)

        let categories = try context.fetch(FetchDescriptor<Category>())
        let account = try context.fetch(FetchDescriptor<Account>()).first
        func category(_ name: String) -> Category? {
            categories.first { $0.name == name }
        }

        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        }

        category("Alimentação")?.monthlyBudget = 300
        category("Lazer")?.monthlyBudget = 30
        category("Carro")?.monthlyBudget = 150

        let samples = [
            FinanceTransaction(title: "Salário", amount: 1850, kind: .income, date: daysAgo(3), category: category("Salário"), account: account),
            FinanceTransaction(title: "Mercadona", amount: 62.40, kind: .expense, date: daysAgo(0), category: category("Alimentação"), account: account),
            FinanceTransaction(title: "Gasolina", amount: 55, kind: .expense, date: daysAgo(1), category: category("Carro"), account: account),
            FinanceTransaction(title: "Spotify", amount: 10.99, kind: .expense, date: daysAgo(2), category: category("Assinaturas"), account: account),
            FinanceTransaction(title: "Jantar", amount: 38.50, kind: .expense, date: daysAgo(5), category: category("Lazer"), account: account),
        ]
        samples.forEach(context.insert)

        context.insert(
            Bill(
                title: "Renda",
                amount: 750,
                dueDate: calendar.date(byAdding: .day, value: 3, to: .now) ?? .now,
                recurrence: .monthly,
                category: category("Casa"),
                account: account
            )
        )

        context.insert(
            Bill(
                title: "Spotify",
                amount: 10.99,
                dueDate: calendar.date(byAdding: .day, value: 12, to: .now) ?? .now,
                recurrence: .monthly,
                isSubscription: true,
                category: category("Assinaturas"),
                account: account
            )
        )
        context.insert(
            Bill(
                title: "iCloud+",
                amount: 35,
                dueDate: calendar.date(byAdding: .month, value: 4, to: .now) ?? .now,
                recurrence: .yearly,
                isSubscription: true,
                currencyCode: "BRL",
                category: category("Assinaturas"),
                account: account
            )
        )

        // Projeto com tarefas em todas as colunas, e uma tarefa avulsa.
        let app = Project(name: "Mynik", details: "Dashboard pessoal para iOS e macOS.", symbolName: "laptopcomputer", color: .indigo)
        context.insert(app)
        [
            ProjectTask(title: "Notas com blocos", status: .doing, priority: .high, dueDate: .now, project: app),
            ProjectTask(title: "Metas ligadas às Finanças", status: .todo, project: app),
            ProjectTask(title: "Kanban de projetos", status: .done, project: app),
            ProjectTask(title: "Renovar o seguro do carro", dueDate: daysAgo(1)),
        ].forEach(context.insert)

        // Metas: uma manual com prazo e uma ligada à categoria Lazer.
        let trip = Goal(title: "Viagem ao Brasil", targetAmount: 2500, deadline: calendar.date(byAdding: .month, value: 8, to: .now), symbolName: "airplane", color: .teal)
        trip.manualAmount = 900
        context.insert(trip)
        context.insert(Goal(title: "Jantares fora", targetAmount: 120, source: .category, symbolName: "fork.knife", color: .purple, startDate: daysAgo(30), category: category("Lazer")))

        // Notas: uma página com blocos e uma subpágina.
        let ideas = NoteEditing.makeNote(title: "Ideias para a Neloce", in: context)
        ideas.icon = "💡"
        ideas.blocks?.first?.text = "Coleção de **inverno** com fotos novas. Ver [[Fornecedores]]."
        NoteEditing.insertBlock(.heading, text: "Próximos passos", in: ideas, context: context)
        NoteEditing.insertBlock(.checklist, text: "Encomendar amostras", in: ideas, context: context)
        NoteEditing.insertBlock(.checklist, text: "Sessão fotográfica", in: ideas, context: context).isChecked = true
        let supplier = NoteEditing.makeNote(title: "Fornecedores", parent: ideas, in: context)
        supplier.icon = "🗂️"
        NoteLinks.toggle(app, in: ideas)

        // Carro com abastecimentos (para o consumo), uma manutenção e prazos.
        let car = Vehicle(name: "Golf", plate: "1234 LMN", fuelType: .gasoline95, initialOdometer: 84_200)
        context.insert(car)
        for (days, km, liters, cost, full) in [(40, 84_200, 42.0, 66.10, true), (26, 84_830, 40.5, 64.20, true), (12, 85_420, 20.0, 31.80, false), (2, 85_990, 19.8, 31.10, true)] {
            let entry = FuelEntry(date: daysAgo(days), odometer: km, quantity: liters, totalCost: Decimal(cost), isFullTank: full, station: "Repsol")
            context.insert(entry)
            entry.vehicle = car
        }
        let service = MaintenanceRecord(kind: .oil, date: daysAgo(90), odometer: 83_100, cost: 89)
        service.nextDueOdometer = 86_100
        context.insert(service)
        service.vehicle = car
        let inspection = CarDeadline(kind: .inspection, dueDate: calendar.date(byAdding: .day, value: 18, to: .now) ?? .now, amount: 42.50, renewalMonths: 24)
        let insurance = CarDeadline(kind: .insurance, dueDate: calendar.date(byAdding: .month, value: 5, to: .now) ?? .now, amount: 380)
        [inspection, insurance].forEach { deadline in
            context.insert(deadline)
            deadline.vehicle = car
        }

        // Documentos: um a expirar e outro válido.
        context.insert(PersonalDocument(kind: .residence, title: "TIE", number: "Y1234567Z", expiryDate: calendar.date(byAdding: .day, value: 40, to: .now)))
        context.insert(PersonalDocument(kind: .passport, number: "FX123456", expiryDate: calendar.date(byAdding: .year, value: 4, to: .now)))

        // Carreira: candidaturas em vários estados e um curso.
        [
            JobApplication(company: "Glovo", role: "iOS Developer", appliedAt: daysAgo(8), followUpDate: .now),
            JobApplication(company: "Cabify", role: "Mobile Engineer", appliedAt: daysAgo(20), status: .interviewing, followUpDate: calendar.date(byAdding: .day, value: 3, to: .now)),
            JobApplication(company: "Idealista", role: "Swift Developer", appliedAt: daysAgo(35), status: .rejected),
        ].forEach(context.insert)
        let course = Course(title: "Swift Concurrency", provider: "Apple Developer", status: .inProgress)
        course.progress = 0.6
        context.insert(course)

        // Investimentos: um ETF com cotação, cripto e um depósito, e 60 dias de património.
        let etf = Investment(name: "Vanguard FTSE All-World", kind: .etf, ticker: "VWCE.DE", units: 25, investedAmount: 3_600)
        etf.unitPrice = 161.08
        etf.priceUpdatedAt = .now
        let bitcoin = Investment(name: "Bitcoin", kind: .crypto, ticker: "BTC-EUR", units: 0.012, investedAmount: 600)
        bitcoin.unitPrice = 56_160
        bitcoin.priceUpdatedAt = .now
        let deposit = Investment(name: "Depósito a prazo", kind: .deposit, investedAmount: 2_000)
        deposit.manualValue = 2_045
        [etf, bitcoin, deposit].forEach(context.insert)
        for day in stride(from: 60, through: 1, by: -3) {
            let wave = Decimal(Int(sin(Double(day) / 6) * 120))
            context.insert(WealthSnapshot(day: calendar.startOfDay(for: daysAgo(day)), cash: 2_900 + Decimal(60 - day) * 4, invested: 6_200 - Decimal(day) * 5, investmentsValue: 6_400 - Decimal(day) * 3 + wave))
        }

        // Hábitos com sequências diferentes.
        for (name, symbol, color, target, done) in [
            ("Ginásio", "dumbbell", CategoryColor.orange, 4, [0, 1, 3, 5, 6, 8]),
            ("Ler 20 minutos", "book", CategoryColor.blue, 7, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
            ("Sem gastos supérfluos", "eurosign.circle", CategoryColor.green, 5, [1, 2, 4]),
        ] {
            let habit = Habit(name: name, symbolName: symbol, color: color, targetPerWeek: target)
            context.insert(habit)
            for day in done {
                context.insert(HabitCheck(day: calendar.startOfDay(for: daysAgo(day)), habit: habit))
            }
        }

        // Loja de exemplo, já em cache.
        let demo = DemoStoreDataSource()
        let since = calendar.date(byAdding: .day, value: -59, to: calendar.startOfDay(for: .now)) ?? .now
        try StoreCacheWriter.apply(demo.snapshot(since: since), since: since, to: context)

        try context.save()
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content
            .modelContainer(context)
            .environment(StoreSyncCoordinator(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleData: Self { .modifier(SampleData()) }
}
