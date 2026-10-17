import MorseCore
import Observation
import os

enum LampLog {
    static let subsystem = "productions.huyakhuyak.morselamp"
}

/// The one source of truth for the running app: state, its store, and the lamp.
@MainActor @Observable
final class AppModel {
    var state: AppState
    let store: any StateStore
    let launch: LaunchConfiguration
    let lamp = LampState()
    /// Seeded when launched with `--rng-seed`, so drills replay the same prompts.
    @ObservationIgnored var rng: any RandomNumberGenerator

    private let logger = Logger(subsystem: LampLog.subsystem, category: "model")

    init(store: any StateStore, launch: LaunchConfiguration) {
        self.store = store
        self.launch = launch
        if let seed = launch.rngSeed {
            rng = SeededGenerator(seed: seed)
        } else {
            rng = SystemRandomNumberGenerator()
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

    /// Back to K and M, with the rhythm forgotten and no guided rounds pending.
    func resetProgress() {
        state.progress.reset()
        state.estimator = DitEstimator()
        state.guided = nil
        save()
    }

    /// Forget the learned dit length only.
    func relearnRhythm() {
        state.estimator = DitEstimator()
        save()
    }
}
