import Foundation

/// Informação sobre o ambiente em que a app está a correr.
nonisolated enum AppEnvironment {
    /// `true` quando a app é o anfitrião dos testes (Xcode / `xcodebuild test`).
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// Modo de demonstração (`-MynikDemo`): dados de exemplo em memória, para
    /// screenshots e apresentações, sem tocar nos dados reais.
    static let isDemo = ProcessInfo.processInfo.arguments.contains("-MynikDemo")

    /// Preferências descartáveis para os testes, separadas das do utilizador.
    static var testDefaults: UserDefaults {
        UserDefaults(suiteName: "com.domynik.mynik.tests") ?? .standard
    }

    /// Preferências da app (as de teste quando corre como anfitrião dos testes).
    static var defaults: UserDefaults {
        if isRunningTests { return testDefaults }
        if isDemo { return UserDefaults(suiteName: "com.domynik.mynik.demo") ?? .standard }
        return .standard
    }
}
