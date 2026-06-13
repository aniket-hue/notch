import SwiftUI

/// Visual constants from the OpenNook design: pure-black glass with an orange accent.
enum Theme {
    /// #ff8a5b — the signature accent.
    static let accent = Color(red: 255 / 255, green: 138 / 255, blue: 91 / 255)

    // Text tiers (white at varying opacity), matching the design.
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.4)
    static let label = Color.white.opacity(0.5)

    // Bars / tracks.
    static let trackBg = Color.white.opacity(0.1)
    static let barFill = Color.white.opacity(0.5)

    static let monoValue = Font.system(size: 12, design: .monospaced)
}
