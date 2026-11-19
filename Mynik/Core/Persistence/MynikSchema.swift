import SwiftData

/// Versão 1 do esquema. Novas versões entram em `MynikMigrationPlan`.
nonisolated enum MynikSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [FinanceTransaction.self, Category.self, Account.self, Bill.self]
    }
}

nonisolated enum MynikMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MynikSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
