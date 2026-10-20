import Foundation
import Testing
import MorseCore
@testable import MorseLamp

@MainActor
struct AppModelTests {
    @Test func automaticAnswerModeSwitchesAtTen() {
        let m = AppModel(store: MemoryStateStore(), launch: .init(arguments: []))
        #expect(m.resolvedAnswerMode() == .choices)
        m.state = LaunchConfiguration.fixtures["tenUnlocked"]!()
        #expect(m.resolvedAnswerMode() == .keyboard)
        m.state.settings.answerMode = .choices
        #expect(m.resolvedAnswerMode() == .choices)
    }

    @Test func resetClearsEverythingButKAndM() {
        let store = MemoryStateStore()
        let m = AppModel(store: store, launch: .init(arguments: ["MorseLamp", "--fixture", "tenUnlocked"]))
        m.state.estimator = DitEstimator(dit: 0.2)
        m.resetProgress()
        #expect(m.state.progress == .initial)
        #expect(m.state.estimator == DitEstimator())
        #expect(m.state.guided == nil)
        // The first-run hints come back too; only settings survive a reset.
        #expect(!m.state.hasKeyed)
        #expect(!m.state.hasListened)
        #expect(m.state.settings.answerMode == .automatic)
        #expect(store.saved.last == m.state)
    }

    @Test func aboutToUnlockFixtureUnlocksOnOneMoreKeying() {
        var s = LaunchConfiguration.fixtures["aboutToUnlock"]!()
        #expect(!s.progress.isSetSolid(UnlockPace.standard.rule))
        s.progress.log("M", .keying, correct: true, rule: UnlockPace.standard.rule)
        #expect(s.progress.pendingUnlock)
        #expect(AppModel(store: MemoryStateStore(), launch: .init(arguments: [])).rule == UnlockPace.standard.rule)
    }

    @Test func loggingSubsystemIsTheBundleIdentifier() {
        #expect(LampLog.subsystem == Bundle.main.bundleIdentifier)
    }

    @Test func loadingASolidSaveFlagsTheUnlock() throws {
        // A build-2 learner: 12 correct K and M in both skills is solid under standard but not strict,
        // and the reveal never fired because the file was saved before pendingUnlock existed in this shape.
        var saved = LaunchConfiguration.fixtures["fresh"]!()
        for _ in 0..<12 {
            for s in Skill.allCases {
                saved.progress.log("K", s, correct: true, rule: UnlockPace.strict.rule)
                saved.progress.log("M", s, correct: true, rule: UnlockPace.strict.rule)
            }
        }
        #expect(!saved.progress.pendingUnlock)             // 12 < 20 under strict
        let store = MemoryStateStore()
        try store.save(saved)
        let m = AppModel(store: store, launch: .init(arguments: []))
        #expect(m.state.progress.pendingUnlock)             // solid under standard
    }

    @Test func refreshNeverClearsPending() {
        let m = AppModel(store: MemoryStateStore(), launch: .init(arguments: ["MorseLamp", "--fixture", "aboutToUnlock"]))
        m.state.progress.log("M", .keying, correct: true, rule: m.rule)
        #expect(m.state.progress.pendingUnlock)
        m.state.settings.pace = .strict
        m.refreshUnlock()
        #expect(m.state.progress.pendingUnlock)
        #expect(m.state.progress.unlockedCount == 2)
    }
}
