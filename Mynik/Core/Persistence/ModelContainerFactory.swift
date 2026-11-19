import SwiftData

enum ModelContainerFactory {
    /// Cria o contentor SwiftData da app.
    ///
    /// O sync por iCloud (CloudKit) só é ligado na Fase 6; até lá os modelos
    /// já seguem as regras do CloudKit para que a migração seja trivial.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MynikSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: MynikMigrationPlan.self,
            configurations: configuration
        )
    }
}
