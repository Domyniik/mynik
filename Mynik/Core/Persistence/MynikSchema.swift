import SwiftData

/// Versão 5 do esquema (v0.6): identificador estável (`uid`) em movimentos,
/// categorias, contas, contas a pagar, projetos e metas, para exportar e
/// importar cópias de segurança sem duplicados.
///
/// Usa os modelos atuais da app. Ao publicar uma versão, congela-se uma cópia
/// (como `MynikSchemaV4`) antes de mudar os modelos de novo.
nonisolated enum MynikSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            FinanceTransaction.self, Category.self, Account.self, Bill.self,
            StoreProduct.self, StoreOrder.self, DailyStat.self, StoreCheckout.self,
            Project.self, ProjectTask.self, Goal.self, Note.self, NoteBlock.self,
            Vehicle.self, FuelEntry.self, MaintenanceRecord.self, CarDeadline.self,
            PersonalDocument.self, DocumentPhoto.self, JobApplication.self, Course.self,
            Investment.self, WealthSnapshot.self,
        ]
    }
}

/// Esquema em uso pela app.
typealias MynikSchemaCurrent = MynikSchemaV5

nonisolated enum MynikMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MynikSchemaV1.self, MynikSchemaV2.self, MynikSchemaV3.self, MynikSchemaV4.self, MynikSchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            // Só acrescentam modelos, propriedades com valor por omissão ou
            // relações opcionais: migração automática.
            .lightweight(fromVersion: MynikSchemaV1.self, toVersion: MynikSchemaV2.self),
            .lightweight(fromVersion: MynikSchemaV2.self, toVersion: MynikSchemaV3.self),
            .lightweight(fromVersion: MynikSchemaV3.self, toVersion: MynikSchemaV4.self),
            .lightweight(fromVersion: MynikSchemaV4.self, toVersion: MynikSchemaV5.self),
        ]
    }
}
