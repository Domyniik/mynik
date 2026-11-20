import Foundation
import FoundationModels

/// Estado do modelo de linguagem no dispositivo (Foundation Models).
///
/// Verificado sempre em runtime: o modelo só existe em dispositivos compatíveis,
/// com a Apple Intelligence ligada e o modelo descarregado.
nonisolated enum AppleIntelligence {
    enum Status: Equatable, Sendable {
        case available
        case deviceNotEligible
        case notEnabled
        case modelNotReady
        case unknown

        var isAvailable: Bool { self == .available }

        /// Explicação para as Definições e para o chat.
        var message: String {
            switch self {
            case .available: "Disponível neste dispositivo. Os dados não saem do aparelho."
            case .deviceNotEligible: "Este dispositivo não suporta a Apple Intelligence. O Mynik usa regras e o histórico."
            case .notEnabled: "Liga a Apple Intelligence nas Definições do sistema para usar a IA no dispositivo."
            case .modelNotReady: "O modelo ainda está a ser descarregado. Entretanto o Mynik usa regras e o histórico."
            case .unknown: "A Apple Intelligence não está disponível. O Mynik usa regras e o histórico."
            }
        }
    }

    static var status: Status {
        // Os testes não dependem do modelo do dispositivo.
        if AppEnvironment.isRunningTests { return .unknown }
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.deviceNotEligible): return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): return .notEnabled
        case .unavailable(.modelNotReady): return .modelNotReady
        case .unavailable: return .unknown
        }
    }
}
