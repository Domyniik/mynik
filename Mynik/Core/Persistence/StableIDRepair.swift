import Foundation
import SwiftData

/// Garante que os registos que ganharam `uid` na v0.6 têm cada um o seu.
///
/// A migração do esquema dá a todos os registos antigos o mesmo valor por
/// omissão; aqui cada repetido (ou vazio) recebe um identificador novo.
/// Corre uma vez por base de dados.
@MainActor
enum StableIDRepair {
    static func runIfNeeded(in context: ModelContext, defaults: UserDefaults) throws {
        guard !defaults.bool(forKey: SettingsKey.stableIDsRepaired) else { return }
        try run(in: context)
        defaults.set(true, forKey: SettingsKey.stableIDsRepaired)
    }

    static func run(in context: ModelContext) throws {
        try repair(Category.self, in: context, uid: \.uid)
        try repair(Account.self, in: context, uid: \.uid)
        try repair(FinanceTransaction.self, in: context, uid: \.uid)
        try repair(Bill.self, in: context, uid: \.uid)
        try repair(Project.self, in: context, uid: \.uid)
        try repair(Goal.self, in: context, uid: \.uid)
        if context.hasChanges { try context.save() }
    }

    private static func repair<M: PersistentModel>(
        _: M.Type,
        in context: ModelContext,
        uid: ReferenceWritableKeyPath<M, String>
    ) throws {
        var seen = Set<String>()
        for model in try context.fetch(FetchDescriptor<M>()) {
            if model[keyPath: uid].isEmpty || seen.contains(model[keyPath: uid]) {
                model[keyPath: uid] = UUID().uuidString
            }
            seen.insert(model[keyPath: uid])
        }
    }
}
