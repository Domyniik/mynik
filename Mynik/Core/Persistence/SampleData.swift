import SwiftData
import SwiftUI

/// Dados de exemplo para as previews do Xcode.
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
