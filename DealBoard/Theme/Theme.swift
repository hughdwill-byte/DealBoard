import SwiftUI

/// Semantic colours for the whole app, each with an explicit light + dark
/// variant. Deliberately warm and appetising — no blue/purple/teal, no gradients.
/// Accent is a burnt terracotta; the three deal types get amber / forest green /
/// warm taupe so they read as distinct but belong to the same family.
enum Theme {
    // MARK: Surfaces
    static let background = dynamic(light: 0xFBF6EE, dark: 0x1A1815)
    static let secondaryBackground = dynamic(light: 0xF3EADB, dark: 0x262320)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x2E2A25)

    // MARK: Text
    static let text = dynamic(light: 0x2A2419, dark: 0xF3ECE0)
    static let secondaryText = dynamic(light: 0x7A6F5C, dark: 0xB6A992)

    // MARK: Accent + type colours
    static let accent = dynamic(light: 0xB4552D, dark: 0xD9743F)   // burnt terracotta
    static let food   = dynamic(light: 0xC08017, dark: 0xE0A23C)   // warm amber
    static let drink  = dynamic(light: 0x3E6B4F, dark: 0x5C9370)   // deep forest green
    static let both   = dynamic(light: 0x8A6A4A, dark: 0xB08A63)   // warm taupe
    static let other  = dynamic(light: 0xA5545A, dark: 0xC77F84)   // warm rosewood

    /// Build a `Color` that resolves differently in light vs dark mode.
    private static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
