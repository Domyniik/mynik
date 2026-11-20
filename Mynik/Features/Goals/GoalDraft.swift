import Foundation

/// Cópia editável de uma meta, usada pelo formulário.
struct GoalDraft {
    static let symbols = [
        "target", "airplane", "car", "house", "laptopcomputer", "iphone", "gift", "graduationcap",
        "heart", "banknote", "shield", "camera", "bicycle", "sparkles", "storefront", "fork.knife",
    ]

    var title = ""
    var targetAmount: Decimal = 0
    var currencyCode = Currency.defaultCode
    var hasDeadline = false
    var deadline = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    var symbolName = "target"
    var color: CategoryColor = .green
    var source: GoalSource = .manual
    var manualAmount: Decimal = 0
    var startDate = Date.now
    var account: Account?
    var category: Category?

    var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, targetAmount > 0 else { return false }
        switch source {
        case .manual: return manualAmount >= 0
        case .account: return account != nil
        case .category: return category != nil
        }
    }

    init() {}

    init(_ goal: Goal) {
        title = goal.title
        targetAmount = goal.targetAmount
        currencyCode = goal.currencyCode
        hasDeadline = goal.deadline != nil
        deadline = goal.deadline ?? deadline
        symbolName = goal.symbolName
        color = goal.color
        source = goal.source
        manualAmount = goal.manualAmount
        startDate = goal.startDate
        account = goal.account
        category = goal.category
    }

    func apply(to goal: Goal) {
        goal.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.targetAmount = targetAmount
        goal.currencyCode = currencyCode
        goal.deadline = hasDeadline ? deadline : nil
        goal.symbolName = symbolName
        goal.colorName = color.rawValue
        goal.source = source
        goal.manualAmount = manualAmount
        goal.startDate = startDate
        // Só guarda a ligação que a origem usa.
        goal.account = source == .account ? account : nil
        goal.category = source == .category ? category : nil
    }

    func makeGoal() -> Goal {
        let goal = Goal(title: "", targetAmount: 0)
        apply(to: goal)
        return goal
    }
}
