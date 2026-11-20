import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Lê o texto de uma fatura (OCR do Vision, no dispositivo) e extrai os campos.
nonisolated enum ReceiptScanner {
    enum ScanError: LocalizedError {
        case unreadableImage
        case noText

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "Não consegui abrir a imagem."
            case .noText: "Não encontrei texto na imagem. Tenta com mais luz e a fatura direita."
            }
        }
    }

    static func scan(imageData: Data) async throws -> ReceiptParser.Result {
        ReceiptParser.parse(lines: try await recognizeLines(in: imageData))
    }

    /// Linhas de texto, de cima para baixo.
    static func recognizeLines(in imageData: Data) async throws -> [String] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw ScanError.unreadableImage }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "es-ES"), Locale.Language(identifier: "pt-PT")]
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: image, orientation: orientation)
        let lines = observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y } // y cresce para cima
            .compactMap { $0.topCandidates(1).first?.string }
        guard !lines.isEmpty else { throw ScanError.noText }
        return lines
    }
}
