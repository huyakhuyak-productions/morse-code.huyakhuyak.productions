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
    /// Show codes on locked cells and the next cell.
    var codesOnLocked = false
}
