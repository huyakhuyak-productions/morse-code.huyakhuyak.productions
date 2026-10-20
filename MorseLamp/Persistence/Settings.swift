import MorseCore
import SwiftUI

/// How the listening drill asks for the answer.
nonisolated enum AnswerMode: String, Codable, CaseIterable, Sendable {
    /// Choices until ten characters are unlocked, then the keyboard.
    case automatic
    case choices
    case keyboard
}

nonisolated enum Theme: String, Codable, CaseIterable, Sendable {
    case system, dark, light

    /// Nil follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

/// Everything the Settings screen edits. Defaults are the spec's.
nonisolated struct Settings: Codable, Equatable, Sendable {
    var strictTiming = false
    var answerMode = AnswerMode.automatic
    /// Playback speed, PARIS words per minute.
    var wpm = 15
    var pitchHz = 600.0
    var haptics = true
    var theme = Theme.system
    /// Show each letter's code in the grid and the letter sheet. Off is the Koch default: hear a
    /// letter before you see it.
    var showsCodes = false
    /// How quickly new characters unlock.
    var pace = UnlockPace.standard

    init() {}

    /// Every field is optional on the way in, so a file from an older build still loads.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strictTiming = try c.decodeIfPresent(Bool.self, forKey: .strictTiming) ?? strictTiming
        answerMode = try c.decodeIfPresent(AnswerMode.self, forKey: .answerMode) ?? answerMode
        wpm = try c.decodeIfPresent(Int.self, forKey: .wpm) ?? wpm
        pitchHz = try c.decodeIfPresent(Double.self, forKey: .pitchHz) ?? pitchHz
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? haptics
        theme = try c.decodeIfPresent(Theme.self, forKey: .theme) ?? theme
        showsCodes = try c.decodeIfPresent(Bool.self, forKey: .showsCodes) ?? showsCodes
        // An unknown value from a newer build falls back instead of failing the whole file.
        pace = (try? c.decodeIfPresent(UnlockPace.self, forKey: .pace)) ?? pace
    }

    private enum CodingKeys: String, CodingKey {
        case strictTiming, answerMode, wpm, pitchHz, haptics, theme, pace
        /// The switch once governed locked letters only; the key stays so saved files still apply.
        case showsCodes = "codesOnLocked"
    }
}
