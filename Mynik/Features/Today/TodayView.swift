import SwiftData
import SwiftUI

/// Painel do dia: saldo do mês, ações rápidas e cartões de contas, agenda, tarefas, hábitos, metas e loja.
struct TodayView: View {
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]

    @State private var isAddingTransaction = false
    @State private var isAskingMynik = false
    @State private var isShowingReview = false
    @State private var width: CGFloat = 0
    @Environment(AppRouter.self) private var router

    /// Em ecrãs largos (Mac, iPad) os cartões ficam em duas colunas.
    private var usesTwoColumns: Bool { width >= 760 }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.l) {
                WeeklyReviewCard()

                BalanceHeroCard(
                    summary: MonthSummary(month: .now, transactions: transactions, converter: converter),
                    trend: SpendingTrend.cumulativeExpenses(month: .now, transactions: transactions, converter: converter)
                )

                TodayQuickActions(
                    addTransaction: { isAddingTransaction = true },
                    ask: { isAskingMynik = true },
                    review: { isShowingReview = true },
                    search: { router.isSearching = true }
                )

                if usesTwoColumns {
                    HStack(alignment: .top, spacing: DS.Spacing.l) {
                        VStack(spacing: DS.Spacing.l) { primaryCards }
                        VStack(spacing: DS.Spacing.l) { secondaryCards }
                    }
                } else {
                    primaryCards
                    secondaryCards
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: DS.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Color.dsBackground)
        .navigationTitle("Hoje")
        #if os(iOS)
        .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.app)))
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Adicionar movimento", systemImage: "plus") {
                    isAddingTransaction = true
                }
            }
        }
        .navigationDestination(isPresented: $isShowingReview) {
            WeeklyReviewView()
        }
        .sheet(isPresented: $isAddingTransaction) {
            TransactionFormView()
        }
        .sheet(isPresented: $isAskingMynik) {
            NavigationStack {
                AskMynikView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fechar", systemImage: "xmark") { isAskingMynik = false }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 560)
            #endif
        }
    }

    @ViewBuilder
    private var primaryCards: some View {
        UpcomingBillsSection(days: 7)
            .environment(\.moduleTint, AppSection.finance.tint)
        TodayCalendarSection()
            .environment(\.moduleTint, .red)
        TodayTasksSection()
            .environment(\.moduleTint, AppSection.projects.tint)
        TodayHabitsSection()
            .environment(\.moduleTint, AppSection.habits.tint)
    }

    @ViewBuilder
    private var secondaryCards: some View {
        TodayStoreSection()
        TodayAgendaSection()
            .environment(\.moduleTint, AppSection.car.tint)
        TodayGoalsSection()
            .environment(\.moduleTint, AppSection.goals.tint)
        RecentTransactionsCard(transactions: Array(transactions.prefix(5)))
            .environment(\.moduleTint, AppSection.finance.tint)
    }
}

/// Últimos movimentos registados.
private struct RecentTransactionsCard: View {
    let transactions: [FinanceTransaction]
    @Environment(AppRouter.self) private var router

    var body: some View {
        DashboardCard("Últimos movimentos", systemImage: "list.bullet.rectangle") {
            Button("Ver todos") { router.open(.finance) }
                .buttonStyle(.borderless)
        } content: {
            if transactions.isEmpty {
                EmptyStateView("Sem movimentos", message: "Regista o primeiro gasto com o botão +.", systemImage: "eurosign.circle")
            } else {
                CardRows(transactions, dividerInset: 46) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
    }
}

/// Ações rápidas em botões de vidro (Liquid Glass): são controlos, não conteúdo.
private struct TodayQuickActions: View {
    let addTransaction: () -> Void
    let ask: () -> Void
    let review: () -> Void
    let search: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Nos tamanhos de acessibilidade os botões passam a uma grelha 2 × 2, sem cortar o texto.
        let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4)
        GlassEffectContainer(spacing: DS.Spacing.s) {
            LazyVGrid(columns: columns, spacing: DS.Spacing.s) {
                action("Gasto", label: "Adicionar movimento", systemImage: "plus.circle.fill", tint: .brand, perform: addTransaction)
                action("Perguntar", label: "Pergunte ao Mynik", systemImage: "sparkles", tint: .purple, perform: ask)
                action("Revisão", label: "Revisão semanal", systemImage: "calendar.badge.checkmark", tint: .orange, perform: review)
                action("Pesquisar", label: "Pesquisar", systemImage: "magnifyingglass", tint: .blue, perform: search)
            }
        }
    }

    private func action(_ title: String, label: String, systemImage: String, tint: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.s)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: DS.Radius.tile))
        .accessibilityLabel(label)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        TodayView()
    }
    .environment(AppRouter())
}
