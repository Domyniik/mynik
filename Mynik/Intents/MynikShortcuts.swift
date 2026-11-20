import AppIntents

/// Frases da Siri e atalhos que aparecem sozinhos na app Atalhos e no Spotlight.
struct MynikShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Gastei em \(\.$category) no \(.applicationName)",
                "Registar gasto em \(\.$category) no \(.applicationName)",
                "Registar gasto no \(.applicationName)",
                "Novo gasto no \(.applicationName)",
            ],
            shortTitle: "Registar gasto",
            systemImageName: "eurosign.circle"
        )
        AppShortcut(
            intent: MonthBalanceIntent(),
            phrases: [
                "Saldo do mês no \(.applicationName)",
                "Quanto gastei este mês no \(.applicationName)",
            ],
            shortTitle: "Saldo do mês",
            systemImageName: "chart.bar"
        )
    }
}
