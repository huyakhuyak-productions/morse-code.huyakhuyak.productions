import Testing
import MorseCore
@testable import MorseLamp

/// Counts `stop()` calls, so a test can tell whether leaving the drill stopped the engine.
@MainActor
final class StopCountingTone: Tone {
    private(set) var stops = 0
    nonisolated init() {}
    func start() async {}
    func stop() { stops += 1 }
    nonisolated func keyDown() {}
    nonisolated func keyUp() {}
    func play(_ schedule: PlaybackSchedule) async -> Bool { true }
    func setPitch(_ hz: Double) {}
}

@MainActor
struct KeyingModelTests {
    /// A keying model over a fixture app with a silent tone, a fixed 0.1 s dit and a frozen clock,
    /// so the 20 ms tick loop never submits on its own; tests call `tick` explicitly.
    private func makeKeying(fixture: String, strict: Bool = false, practice: Character? = nil, guided: GuidedRounds? = nil) -> (KeyingModel, AppModel) {
        let app = AppModel(store: MemoryStateStore(), launch: .init(arguments: ["MorseLamp", "--fixture", fixture, "--rng-seed", "1", "--silent-audio"]))
        app.state.estimator = DitEstimator(dit: 0.1)
        app.state.settings.strictTiming = strict
        app.state.guided = guided
        let model = KeyingModel(app: app, tone: app.tone, haptics: app.haptics, practice: practice, now: { 0 })
        return (model, app)
    }

    /// Keys `code` as timestamped presses, then ticks past the submit gap.
    private func key(_ m: KeyingModel, code: Code, dit: Double, dashLength: Double? = nil) {
        var t = 1000.0
        for element in code.elements {
            let length = element == .dot ? dit : (dashLength ?? 3 * dit)
            m.keyDown(at: t)
            m.keyUp(at: t + length)
            t += length + dit
        }
        m.tick(now: t + 5)
    }

    @Test func matchLogsAndAdvancesAfterHold() async {
        let (m, app) = makeKeying(fixture: "fresh")
        let target = m.target
        key(m, code: Morse.code(for: target)!, dit: 0.1)
        #expect(m.phase == .matched)
        #expect(m.status == "\(target)  \(Morse.code(for: target)!.display)")
        #expect(app.state.progress.record(target, .keying).total == 1)
        #expect(app.state.hasKeyed)
        try? await Task.sleep(for: .milliseconds(900))
        #expect(m.phase == .keying)
        #expect(m.keyed.isEmpty)
    }

    @Test func missShowsHintAndDoesNotLogTheRetry() {
        let (m, app) = makeKeying(fixture: "fresh")
        let t = m.target
        key(m, code: Code(elements: [.dot, .dot, .dot, .dot, .dot, .dot]), dit: 0.1)
        #expect(m.phase == .missed(fault: nil))
        #expect(m.hint == Morse.code(for: t))
        #expect(m.status == "\(t) is \(Morse.code(for: t)!.display)")
        #expect(app.state.progress.record(t, .keying).recent == [false])
        m.nextPrompt()
        #expect(m.target == t)
        #expect(m.hint == Morse.code(for: t))
        #expect(m.status == "\(t) is \(Morse.code(for: t)!.display)")  // stays until the next press
        key(m, code: Morse.code(for: t)!, dit: 0.1)
        #expect(m.phase == .matched)
        #expect(app.state.progress.record(t, .keying).total == 1)  // the miss was logged, the hinted retry was not
    }

    @Test func strictAlmostIsLoggedIncorrect() {
        let (m, app) = makeKeying(fixture: "fresh", strict: true)
        let t = m.target
        key(m, code: Morse.code(for: t)!, dit: 0.1, dashLength: 0.2)  // dashes at 2.0 units
        guard case .missed(let fault) = m.phase else {
            Issue.record("expected .missed, got \(m.phase)")
            return
        }
        #expect(fault?.element == .dash)
        #expect(fault?.problem == .tooShort)
        #expect(m.status.hasPrefix("Right pattern. Dash "))
        #expect(m.status.hasSuffix(" was too short."))
        #expect(app.state.progress.record(t, .keying).recent == [false])
    }

    @Test func pressesDuringHoldAreDiscarded() {
        let (m, _) = makeKeying(fixture: "fresh")
        let code = Morse.code(for: m.target)!
        key(m, code: code, dit: 0.1)
        m.keyDown(at: 2000)
        m.keyUp(at: 2000.1)
        m.tick(now: 2010)
        #expect(m.keyed == code.elements)  // the matched readout stays; the stray press changed nothing
        #expect(m.phase == .matched)
    }

    @Test func backgroundingDiscardsPendingPresses() {
        let (m, _) = makeKeying(fixture: "fresh")
        m.keyDown(at: 1)
        m.keyUp(at: 1.1)
        #expect(m.keyed.count == 1)
        m.disappear()
        #expect(m.keyed.isEmpty)
        m.tick(now: 10)
        #expect(m.phase == .keying)
    }

    @Test func unlockSetsRevealPendingOnlyInNormalMode() {
        let (m, _) = makeKeying(fixture: "aboutToUnlock")
        m.setTarget("M")
        key(m, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(m.revealPending == "R")
        let (p, app2) = makeKeying(fixture: "aboutToUnlock", practice: "M")
        key(p, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(p.revealPending == nil)
        #expect(app2.state.progress.pendingUnlock)
    }

    @Test func guidedRoundsAreNotLogged() {
        let (m, app) = makeKeying(fixture: "fresh", guided: GuidedRounds(drill: .keying, character: "R", remaining: 3))
        #expect(m.target == "R")
        #expect(m.hint == Morse.code(for: "R"))
        #expect(m.mode == .guided("R", remaining: 3))
        key(m, code: Morse.code(for: "R")!, dit: 0.1)
        #expect(app.state.progress.record("R", .keying).total == 0)
        #expect(app.state.guided?.remaining == 2)
    }

    @Test func practiceAsksTenTimesThenEnds() {
        let (m, app) = makeKeying(fixture: "tenUnlocked", practice: "K")
        #expect(m.target == "K")
        for round in 0..<10 {
            key(m, code: Morse.code(for: "K")!, dit: 0.1)
            // The tenth result is shown through its hold like every other; practice ends at the next prompt.
            #expect(!m.didFinishPractice, "round \(round)")
            m.nextPrompt()
        }
        #expect(m.didFinishPractice)
        #expect(app.state.progress.record("K", .keying).total == UnlockPace.standard.rule.newestFloor + 10)  // the fixture's rounds plus 10 practice
    }

    @Test func firstPromptStatusAndMutedStatus() {
        let (m, _) = makeKeying(fixture: "fresh")
        #expect(m.status == "Tap for a dot, hold for a dash")
        let (n, app) = makeKeying(fixture: "tenUnlocked")
        app.lamp.isMuted = true
        n.refreshStatus()
        #expect(n.status == "Sound is off")
        n.keyDown(at: 1)
        n.keyUp(at: 1.1)
        #expect(n.status == "·")
    }

    @Test func bluetoothNoticeShowsOnce() {
        let (m, app) = makeKeying(fixture: "tenUnlocked")
        app.lamp.routeIsBluetooth = true
        m.refreshStatus()
        #expect(m.status == "Headphones over Bluetooth add delay to the key")
        #expect(app.state.bluetoothNoticeShown)
        let (n, _) = makeKeying(fixture: "tenUnlocked")
        n.refreshStatus()
        #expect(n.status.isEmpty)
    }

    /// Lock the phone during the 800 ms hold: coming back must not leave the paddle dead.
    @Test func foregroundDuringTheHoldResumesWithAFreshPrompt() async {
        let (m, app) = makeKeying(fixture: "fresh")
        let target = m.target
        key(m, code: Morse.code(for: target)!, dit: 0.1)
        #expect(m.phase == .matched)
        m.disappear()
        await m.appear()
        #expect(m.phase == .keying)
        #expect(m.keyed.isEmpty)
        #expect(m.target != target)
        #expect(app.state.progress.record(target, .keying).total == 1)
        m.disappear()
    }

    /// The rule became true during practice (or the app died mid-hold): the reveal fires on the next normal prompt.
    @Test func pendingUnlockAtEntryPresentsTheReveal() {
        let (p, app) = makeKeying(fixture: "aboutToUnlock", practice: "M")
        key(p, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(app.state.progress.pendingUnlock)
        let m = KeyingModel(app: app, tone: app.tone, haptics: app.haptics, now: { 0 })
        #expect(m.revealPending == "R")
        #expect(m.revealReady == "R")
        let (g, gapp) = makeKeying(fixture: "aboutToUnlock", guided: GuidedRounds(drill: .keying, character: "R", remaining: 3))
        gapp.state.progress.log("M", .keying, correct: true, rule: UnlockPace.standard.rule)
        let guided = KeyingModel(app: gapp, tone: gapp.tone, haptics: gapp.haptics, now: { 0 })
        #expect(guided.revealPending == nil)  // guided rounds come first
        _ = g
    }

    @Test func nudgeFiresAfterTheHoldOnce() async {
        let (m, app) = makeKeying(fixture: "listeningBehind")
        m.setTarget("M"); key(m, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(m.nudgePending); #expect(!m.nudgeReady)          // matched, still in the hold
        #expect(app.state.nudges.isEmpty)                         // not shown yet
        try? await Task.sleep(for: .milliseconds(900))
        #expect(m.nudgeReady)
        #expect(app.state.nudges.count == 1)
        m.dismissNudge()
        #expect(!m.nudgeReady)
        #expect(app.state.nudges.count == 1)
        m.setTarget("K"); key(m, code: Morse.code(for: "K")!, dit: 0.1)
        #expect(!m.nudgePending)
    }

    /// Leaving during the hold, before the sheet shows, keeps the nudge for the next visit.
    @Test func nudgeLeftDuringTheHoldIsNotSpent() {
        let (m, app) = makeKeying(fixture: "listeningBehind")
        m.setTarget("M"); key(m, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(m.nudgePending)
        m.disappear()
        #expect(app.state.nudges.isEmpty)
        let again = KeyingModel(app: app, tone: app.tone, haptics: app.haptics, now: { 0 })
        again.setTarget("M"); key(again, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(again.nudgePending)
    }

    /// Only a correct answer arms the nudge: a logged miss on the nudge-due progress does not.
    @Test func nudgeIsNotArmedByAMiss() {
        let (m, app) = makeKeying(fixture: "listeningBehind")
        m.setTarget("M"); key(m, code: Morse.code(for: "K")!, dit: 0.1)
        #expect(app.state.progress.record("M", .keying).recent.last == false)
        #expect(!m.nudgePending)
    }

    /// Guided rounds after a reveal are never interrupted by the nudge.
    @Test func nudgeNeverFiresInGuidedRounds() {
        let (m, _) = makeKeying(fixture: "listeningBehind", guided: GuidedRounds(drill: .keying, character: "M", remaining: 3))
        #expect(m.mode == .guided("M", remaining: 3))
        key(m, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(!m.nudgePending)
    }

    @Test func nudgeNeverFiresInPractice() {
        let (m, _) = makeKeying(fixture: "listeningBehind", practice: "M")
        key(m, code: Morse.code(for: "M")!, dit: 0.1)
        #expect(!m.nudgePending)
    }

    /// `SilentTone.keyUp` (which `disappear` calls) also darkens the lamp, so the engine stop is counted directly.
    @Test func handOverKeepsToneRunning() {
        let app = AppModel(store: MemoryStateStore(), launch: .init(arguments: ["MorseLamp", "--fixture", "fresh", "--silent-audio"]))
        let tone = StopCountingTone()
        let m = KeyingModel(app: app, tone: tone, haptics: app.haptics, now: { 0 })
        m.handOver(); m.disappear()
        #expect(tone.stops == 0)
        let plain = KeyingModel(app: app, tone: tone, haptics: app.haptics, now: { 0 })
        plain.disappear()
        #expect(tone.stops == 1)
    }
}
