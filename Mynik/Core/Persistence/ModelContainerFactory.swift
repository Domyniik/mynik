import Foundation
import SwiftData

enum ModelContainerFactory {
    /// Cria o contentor SwiftData da app.
    ///
    /// Sem CloudKit (exige o plano pago da Apple): o sync é feito com o Supabase
    /// (`SyncEngine`). Os modelos seguem as regras do CloudKit por herança.
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
