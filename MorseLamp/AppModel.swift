import MorseCore
import Observation
import os

nonisolated enum LampLog {
    static let subsystem = "productions.huyakhuyak.MorseLamp"
}

/// The one source of truth for the running app: state, its store, and the lamp.
@MainActor @Observable
final class AppModel {
    var state: AppState
    let store: any StateStore
    let launch: LaunchConfiguration
    /// The real engine, or the silent one under `--silent-audio`.
    let tone: any Tone
    let haptics = Haptics()
    let lamp = LampState()
    /// The unlock rule the learner's pace setting selects.
    var rule: UnlockRule { state.settings.pace.rule }

    /// How far the learner is from the next unlock under the current rule.
    var outlook: UnlockOutlook { UnlockOutlook(progress: state.progress, rule: rule) }
    /// Seeded when launched with `--rng-seed`, so drills replay the same prompts.
    @ObservationIgnored var rng: AnyRandomNumberGenerator

    private let logger = Logger(subsystem: LampLog.subsystem, category: "model")

    init(store: any StateStore, launch: LaunchConfiguration) {
        self.store = store
        self.launch = launch
        let lamp = self.lamp
        tone = launch.silentAudio ? SilentTone(lamp: lamp) : ToneEngine(lamp: lamp, pitchHz: Settings().pitchHz)
        if let seed = launch.rngSeed {
            rng = AnyRandomNumberGenerator(SeededGenerator(seed: seed))
        } else {
            rng = AnyRandomNumberGenerator(SystemRandomNumberGenerator())
        }
        if let fixture = launch.fixture.flatMap({ LaunchConfiguration.fixtures[$0] }) {
            state = fixture()
        } else if launch.resetState {
            state = AppState()
        } else {
            do {
                state = try store.load() ?? AppState()
            } catch {
                logger.error("Saved state unreadable, starting fresh: \(error, privacy: .public)")
                state = AppState()
            }
        }
        refreshUnlock()
    }

    /// Flags the reveal when the set is already solid under the current pace. Never clears it.
    func refreshUnlock() {
        state.progress.refreshPendingUnlock(rule: rule)
    }

    /// Persists the current state. Failures are logged; the UI never sees them.
    func save() {
        do {
            try store.save(state)
        } catch {
            logger.error("Save failed: \(error, privacy: .public)")
        }
    }

    /// Automatic means choices until ten characters are unlocked, then the keyboard.
    func resolvedAnswerMode() -> AnswerMode {
        switch state.settings.answerMode {
        case .automatic: state.progress.unlockedCount < 10 ? .choices : .keyboard
        case .choices: .choices
        case .keyboard: .keyboard
        }
    }

    /// True when more of this drill will not unlock the next letter, the other drill would, and
    /// no nudge has been shown yet in this drill for the newest letter. No side effects.
    func isNudgeDue(in drill: Drill) -> Bool {
        let skill: Skill = switch drill {
        case .keying: .keying
        case .listening: .listening
        }
        return UnlockOutlook.suggestsSwitching(from: skill, progress: state.progress, rule: rule)
            && !state.nudges.contains(Nudge(drill: drill, character: state.progress.newest))
    }

    /// The nudge is on screen: it never shows again in this drill for the newest letter.
    func recordNudge(in drill: Drill) {
        state.nudges.append(Nudge(drill: drill, character: state.progress.newest))
        save()
    }

    /// Back to K and M, with the rhythm forgotten, no guided rounds or nudges pending and the first-run hints back.
    func resetProgress() {
        state.progress.reset()
        state.estimator = DitEstimator()
        state.guided = nil
        state.nudges = []
        state.hasKeyed = false
        state.hasListened = false
        save()
    }

    /// Forget the learned dit length only.
    func relearnRhythm() {
        state.estimator = DitEstimator()
        save()
    }
}

/// Type-erased generator so the picker's `inout some RandomNumberGenerator` can take either source.
nonisolated struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator

    init(_ base: some RandomNumberGenerator) {
        self.base = base
    }

    mutating func next() -> UInt64 {
        base.next()
    }
}
