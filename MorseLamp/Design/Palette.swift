import MorseCore
import SwiftUI

/// The spec's colour tokens for one appearance.
struct Palette: Equatable, Sendable {
    let bg: Color
    let fg: Color
    let fgDim: Color
    /// Cells and tracks.
    let muted: Color
    /// Rings and switches in the off state.
    let muted2: Color
    /// Cobalt. Never used for text under 24 pt; use `accentText` there.
    let accent: Color
    let accentText: Color
    let bad: Color
    /// Strict timing "almost".
    let warn: Color
    /// Paddle and primary buttons.
    let key: Color
    let keyText: Color

    static let dark = Palette(
        bg: Color(hex: 0x000000), fg: Color(hex: 0xFFFFFF), fgDim: Color(hex: 0x8C8C8C),
        muted: Color(hex: 0x1F1F1F), muted2: Color(hex: 0x3A3A3A),
        accent: Color(hex: 0x3D5BFF), accentText: Color(hex: 0x7D90FF),
        bad: Color(hex: 0xFF4D3D), warn: Color(hex: 0xFFB020),
        key: Color(hex: 0xFFFFFF), keyText: Color(hex: 0x000000)
    )

    static let light = Palette(
        bg: Color(hex: 0xFFFFFF), fg: Color(hex: 0x000000), fgDim: Color(hex: 0x6E6E6E),
        muted: Color(hex: 0xEFEFEF), muted2: Color(hex: 0xD9D9D9),
        accent: Color(hex: 0x1F3BE6), accentText: Color(hex: 0x1A33C4),
        bad: Color(hex: 0xE5301F), warn: Color(hex: 0xC77700),
        key: Color(hex: 0x000000), keyText: Color(hex: 0xFFFFFF)
    )

    static func resolve(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }

    /// Screen background while a tone sounds: accent mixed 18 % into bg.
    var lit: Color { bg.mix(with: accent, by: 0.18) }

    /// Grid cell fill by mastery level.
    func cellFill(level: Level) -> Color {
        switch level {
        case .new: muted
        case .learning: muted.mix(with: accent, by: 0.28)
        case .nearly: muted.mix(with: accent, by: 0.62)
        case .mastered: accent
        }
    }
}

extension Color {
    /// `Color(hex: 0x3D5BFF)`, opaque sRGB.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension EnvironmentValues {
    /// Set once by `MorseLampApp` from the colour scheme; every screen reads it.
    @Entry var palette: Palette = .dark
}
