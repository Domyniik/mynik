import SwiftData

/// Versão 4 do esquema (v0.5): acrescenta carro, documentos, carreira e investimentos.
///
/// Usa os modelos atuais da app. Ao publicar uma versão, congela-se uma cópia
/// (como `MynikSchemaV3`) antes de mudar os modelos de novo.
nonisolated enum MynikSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

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
typealias MynikSchemaCurrent = MynikSchemaV4

nonisolated enum MynikMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MynikSchemaV1.self, MynikSchemaV2.self, MynikSchemaV3.self, MynikSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            // Só acrescentam modelos, propriedades com valor por omissão ou
            // relações opcionais: migração automática.
            .lightweight(fromVersion: MynikSchemaV1.self, toVersion: MynikSchemaV2.self),
            .lightweight(fromVersion: MynikSchemaV2.self, toVersion: MynikSchemaV3.self),
            .lightweight(fromVersion: MynikSchemaV3.self, toVersion: MynikSchemaV4.self),
        ]
    }
}
