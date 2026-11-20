import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reduz imagens antes de as guardar numa nota (sem UIKit nem AppKit).
nonisolated enum ImageDownsampler {
    /// Lado maior máximo, em píxeis.
    static let maxPixelSize = 1600

    /// Devolve um JPEG com o lado maior até `maxPixelSize`, ou `nil` se os dados não forem uma imagem.
    static func jpegData(from data: Data, maxPixelSize: Int = maxPixelSize, quality: Double = 0.8) -> Data? {
        guard let image = cgImage(from: data, maxPixelSize: maxPixelSize) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Imagem para mostrar, já reduzida (com a orientação EXIF aplicada).
    static func cgImage(from data: Data, maxPixelSize: Int = maxPixelSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
