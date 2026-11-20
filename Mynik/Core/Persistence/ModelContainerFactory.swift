import Foundation
import SwiftData

enum ModelContainerFactory {
    /// Cria o contentor SwiftData da app.
    ///
    /// O sync por iCloud (CloudKit) só é ligado na Fase 6; até lá os modelos
    /// já seguem as regras do CloudKit para que a migração seja trivial.
    ///
    /// - Parameter url: ficheiro da base de dados (por omissão, o da app).
    static func make(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MynikSchemaCurrent.self)
        let configuration = if let url {
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: MynikMigrationPlan.self,
            configurations: configuration
        )
    }
}
