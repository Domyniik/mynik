import SwiftData

/// Versão 3 do esquema (v0.4): acrescenta projetos, tarefas, metas e notas.
///
/// Usa os modelos atuais da app. Ao publicar uma versão, congela-se uma cópia
/// (como `MynikSchemaV2`) antes de mudar os modelos de novo.
nonisolated enum MynikSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            FinanceTransaction.self, Category.self, Account.self, Bill.self,
            StoreProduct.self, StoreOrder.self, DailyStat.self, StoreCheckout.self,
            Project.self, ProjectTask.self,
        ]
    }
}

/// Esquema em uso pela app.
typealias MynikSchemaCurrent = MynikSchemaV3

nonisolated enum MynikMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MynikSchemaV1.self, MynikSchemaV2.self, MynikSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            // Só acrescentam modelos, propriedades com valor por omissão ou
            // relações opcionais: migração automática.
            .lightweight(fromVersion: MynikSchemaV1.self, toVersion: MynikSchemaV2.self),
            .lightweight(fromVersion: MynikSchemaV2.self, toVersion: MynikSchemaV3.self),
        ]
    }
}
