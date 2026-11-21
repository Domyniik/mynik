#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Área de transferência do sistema (iOS e Mac).
enum Clipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
