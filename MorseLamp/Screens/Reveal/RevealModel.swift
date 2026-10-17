import MorseCore
import Observation
import SwiftUI

/// The unlock reveal: hush, two signals, a guess, the glyph, two hearings with the code, a caption.
/// The unlock itself happens in `init` and is saved at once, so closing the app mid-reveal keeps it.
@MainActor @Observable
final class RevealModel {
    enum Step: Equatable {
        case hush
        /// The code sounds without its shape; `1` after the hush, `2` after the beat.
        case signal(Int)
        case beat
        case guess
        case decided(correct: Bool)
        case reveal
        /// The code sounds with its shape highlighted element by element; `1` then `2`.
        case hearing(pass: Int)
        case caption
    }

    static let hush: Duration = .milliseconds(700)
    static let beat: Duration = .milliseconds(900)
    static let decision: Duration = .milliseconds(900)
    static let landing: Duration = .milliseconds(520)
    static let betweenHearings: Duration = .milliseconds(700)
    static let guidedRounds = 3

    let character: Character
    let from: Drill
    /// The count after this unlock; shown from the reveal step on.
    let unlockedCount: Int
    private(set) var step: Step = .hush
    private(set) var lead = "A new letter. Listen."
    /// The new character and two distractors, shuffled; filled at the guess.
    private(set) var options: [Character] = []
    private(set) var picked: Character?
    private(set) var caption: [HomeSummary.Run] = []

    /// The element sounding right now, while the code is on screen.
    var highlighted: Int? {
        switch step {
        case .hearing, .caption: app.lamp.litElementIndex
        default: nil
        }
    }

    var code: Code { Morse.code(for: character) ?? Code(elements: []) }

    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private let tone: any Tone
    @ObservationIgnored private let haptics: Haptics
    @ObservationIgnored private var isReplaying = false

    init(app: AppModel, from: Drill, tone: any Tone, haptics: Haptics) {
        self.app = app
        self.from = from
        self.tone = tone
        self.haptics = haptics
        let unlocked = app.state.progress.unlockNext() ?? app.state.progress.newest
        character = unlocked
        unlockedCount = app.state.progress.unlockedCount
        app.save()
    }

    // MARK: Sequence

    /// Hush, signal, beat, signal, then wait for a guess. Stops quietly when cancelled.
    func run() async {
        guard step == .hush else { return }
        do {
            try await Task.sleep(for: Self.hush)
            step = .signal(1)
            await play()
            try Task.checkCancellation()
            step = .beat
            lead = "Got it? Once more."
            announce(lead)
            try await Task.sleep(for: Self.beat)
            step = .signal(2)
            await play()
            try Task.checkCancellation()
            options = ([character] + CharacterPicker.distractors(for: character, progress: app.state.progress, using: &app.rng)).shuffled(using: &app.rng)
            step = .guess
            lead = "Which one was it?"
            announce(lead)
        } catch {
            // Cancelled: the view is gone. The unlock already stands.
        }
    }

    /// Plays the code again: during the guess without its shape, under the caption with it.
    func replay() async {
        guard step == .guess || step == .caption, !isReplaying else { return }
        isReplaying = true
        defer { isReplaying = false }
        await play()
    }

    /// The guess is never scored. Right or wrong, the character is revealed and heard twice.
    func pick(_ guess: Character) async {
        guard step == .guess, options.contains(guess) else { return }
        picked = guess
        let correct = guess == character
        step = .decided(correct: correct)
        lead = correct ? "You guessed it." : "It was \(character), not \(guess)."
        announce(lead)
        try? await Task.sleep(for: Self.decision)
        step = .reveal
        haptics.reveal()
        announce("\(character), \(code.spokenDescription)")
        try? await Task.sleep(for: Self.landing)
        step = .hearing(pass: 1)
        await play()
        try? await Task.sleep(for: Self.betweenHearings)
        step = .hearing(pass: 2)
        await play()
        caption = [
            HomeSummary.Run(text: lead + " ", isBold: false),
            HomeSummary.Run(text: String(character), isBold: true),
            HomeSummary.Run(text: " joins your set, \(unlockedCount) of \(Morse.kochOrder.count).", isBold: false),
        ]
        step = .caption
        announce(caption.map(\.text).joined())
    }

    /// Three guided rounds in the drill the reveal came from.
    func keepGoing() {
        app.state.guided = GuidedRounds(drill: from, character: character, remaining: Self.guidedRounds)
        app.save()
    }

    private func play() async {
        _ = await tone.play(PlaybackSchedule(code: code, wpm: app.state.settings.wpm))
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
