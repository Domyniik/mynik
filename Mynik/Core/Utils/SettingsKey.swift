import Foundation

/// Chaves das preferências guardadas em `UserDefaults` / `@AppStorage`.
nonisolated enum SettingsKey {
    static let billRemindersEnabled = "billRemindersEnabled"
    static let billReminderDaysBefore = "billReminderDaysBefore"
}
