import UIKit

/// Área de transferência do sistema.
enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
