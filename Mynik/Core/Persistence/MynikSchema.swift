import SwiftData

/// Versão 2 do esquema (v0.3): acrescenta a cache da loja Shopify.
///
/// Usa os modelos atuais da app. Ao publicar uma versão, congela-se uma cópia
/// (como `MynikSchemaV1`) antes de mudar os modelos de novo.
nonisolated enum MynikSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            FinanceTransaction.self, Category.self, Account.self, Bill.self,
            StoreProduct.self, StoreOrder.self, DailyStat.self,
        ]
    }
}

/// Esquema em uso pela app.
typealias MynikSchemaCurrent = MynikSchemaV2

nonisolated enum MynikMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MynikSchemaV1.self, MynikSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            // Só acrescenta modelos novos: migração automática.
            .lightweight(fromVersion: MynikSchemaV1.self, toVersion: MynikSchemaV2.self),
        ]
    }
}
