import SwiftUI

enum Theme {

    static let accent = Color(red: 1.0, green: 0.33, blue: 0.62)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.4)
    static let label = Color.white.opacity(0.5)

    static let trackBg = Color.white.opacity(0.1)
    static let barFill = Color.white.opacity(0.5)

    static let monoValue = Font.system(size: 12, design: .monospaced)
    
    static let black = Color.black
}
