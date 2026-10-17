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
        #expect(!s.progress.isSetSolid)
        s.progress.log("M", .keying, correct: true)
        #expect(s.progress.pendingUnlock)
    }
}
