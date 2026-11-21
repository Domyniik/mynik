import Foundation
import SwiftData
import BackgroundTasks

/// Atualização da loja em segundo plano, para avisar de vendas sem abrir a app.
///
/// `BGAppRefreshTask`: o sistema decide quando corre, em geral de hora a
/// hora se a app é usada com frequência.
enum StoreBackgroundRefresh {
    static let taskIdentifier = "com.domynik.mynik.store-refresh"
    static let interval: TimeInterval = 30 * 60

    /// Pede ao sistema a próxima atualização (iOS).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date.now.addingTimeInterval(interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Corre uma atualização (só com a loja real ligada; os dados de exemplo não mudam).
    @MainActor
    static func run(container: ModelContainer, coordinator: StoreSyncCoordinator) async {
        schedule()
        guard ShopifyCredentials.load() != nil else { return }
        await coordinator.refresh(in: container.mainContext)
    }
}
