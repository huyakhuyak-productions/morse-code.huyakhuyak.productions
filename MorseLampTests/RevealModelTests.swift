import Testing
import MorseCore
@testable import MorseLamp

@MainActor
struct RevealModelTests {
    /// An `aboutToUnlock` app whose one missing M keying has just been logged, so the set is solid.
    private func makeApp() -> (AppModel, MemoryStateStore) {
        let store = MemoryStateStore()
        let app = AppModel(store: store, launch: .init(arguments: ["MorseLamp", "--fixture", "aboutToUnlock", "--rng-seed", "1", "--silent-audio"]))
        app.state.settings.wpm = 30  // short signals
        app.state.progress.log("M", .keying, correct: true, rule: UnlockPace.standard.rule)
        return (app, store)
    }

    private func makeReveal(from drill: Drill = .keying) -> (RevealModel, AppModel) {
        let (app, _) = makeApp()
        let model = RevealModel(app: app, from: drill, tone: SilentTone(lamp: app.lamp), haptics: app.haptics)
        return (model, app)
    }

    /// Runs the sequence in a task and returns once the model is waiting for a guess.
    private func driveToGuess(_ model: RevealModel) async {
        let task = Task { await model.run() }
        await untilStep(model, .guess, timeout: 5)
        _ = await task.value
    }

    private func untilStep(_ model: RevealModel, _ step: RevealModel.Step, timeout: Double) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(timeout)
        while model.step != step, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func initUnlocksImmediatelyAndPersists() {
        let (app, store) = makeApp()
        #expect(app.state.progress.pendingUnlock)
        let r = RevealModel(app: app, from: .keying, tone: SilentTone(lamp: app.lamp), haptics: app.haptics)
        #expect(r.character == "R")
        #expect(app.state.progress.unlockedCount == 3)
        #expect(!app.state.progress.pendingUnlock)
        #expect(store.saved.last == app.state)
    }

    @Test func sequenceLeadsAndOptions() async {
        let (r, _) = makeReveal()
        #expect(r.step == .hush)
        #expect(r.lead == "A new letter. Listen.")
        let task = Task { await r.run() }
        await untilStep(r, .beat, timeout: 5)
        #expect(r.lead == "Got it? Once more.")
        await untilStep(r, .guess, timeout: 5)
        task.cancel()
        #expect(r.lead == "Which one was it?")
        #expect(r.options.count == 3)
        #expect(r.options.contains("R"))
        // Distractors come from the locked set, never from K or M.
        #expect(!r.options.contains("K") && !r.options.contains("M"))
    }

    @Test func rightAndWrongDecisions() async {
        let (r, _) = makeReveal()
        await driveToGuess(r)
        await r.pick("R")
        #expect(r.picked == "R")
        #expect(r.lead == "You guessed it.")
        #expect(r.step == .caption)
        #expect(r.caption.map(\.text).joined() == "You guessed it. R joins your set, 3 of 36.")
        #expect(r.caption.first { $0.isBold }?.text == "R")

        let (w, _) = makeReveal()
        await driveToGuess(w)
        let wrong = w.options.first { $0 != "R" }!
        await w.pick(wrong)
        #expect(w.lead == "It was R, not \(wrong).")
        #expect(w.caption.map(\.text).joined() == "It was R, not \(wrong). R joins your set, 3 of 36.")
    }

    @Test func pickIsIgnoredOutsideTheGuess() async {
        let (r, _) = makeReveal()
        await r.pick("R")
        #expect(r.step == .hush)
        #expect(r.picked == nil)
    }

    @Test func keepGoingSetsGuidedRounds() {
        let (r, app) = makeReveal(from: .listening)
        r.keepGoing()
        #expect(app.state.guided == GuidedRounds(drill: .listening, character: "R", remaining: 3))
    }

    @Test func guessIsNeverLogged() async {
        let (r, app) = makeReveal()
        await driveToGuess(r)
        await r.pick("R")
        #expect(app.state.progress.record("R", .keying).total == 0)
        #expect(app.state.progress.record("R", .listening).total == 0)
        #expect(app.state.guided == nil)  // only "Keep going" schedules the guided rounds
    }

    @Test func drillsResumeInGuidedModeAfterKeepGoing() async {
        let (r, app) = makeReveal(from: .keying)
        let keying = KeyingModel(app: app, tone: app.tone, haptics: app.haptics, now: { 0 })
        keying.revealPending = "R"
        #expect(keying.mode == .normal)
        r.keepGoing()
        keying.resumeAfterReveal()
        #expect(keying.revealPending == nil)
        #expect(keying.mode == .guided("R", remaining: 3))
        #expect(keying.target == "R")
        #expect(keying.hint == Morse.code(for: "R"))

        let (l, lapp) = makeReveal(from: .listening)
        let listening = ListeningModel(app: lapp, tone: lapp.tone, haptics: lapp.haptics)
        listening.revealPending = "R"
        #expect(listening.mode == .normal)
        l.keepGoing()
        await listening.resumeAfterReveal()
        #expect(listening.revealPending == nil)
        #expect(listening.mode == .guided("R", remaining: 3))
        #expect(listening.answer == "R")
        #expect(listening.revealedCode == Morse.code(for: "R"))
        #expect(listening.phase == .awaiting)
        listening.disappear()
    }
}
