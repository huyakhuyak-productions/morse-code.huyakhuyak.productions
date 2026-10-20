import Testing
import MorseCore
@testable import MorseLamp

/// A tone whose playback is cut immediately, as an audio interruption would.
@MainActor
private final class InterruptingTone: Tone {
    nonisolated init() {}
    func start() async {}
    func stop() {}
    nonisolated func keyDown() {}
    nonisolated func keyUp() {}
    func play(_ schedule: PlaybackSchedule) async -> Bool { false }
    func setPitch(_ hz: Double) {}
}

@MainActor
struct ListeningModelTests {
    private func makeListening(fixture: String, tone: (any Tone)? = nil, guided: GuidedRounds? = nil) -> (ListeningModel, AppModel) {
        let app = AppModel(store: MemoryStateStore(), launch: .init(arguments: ["MorseLamp", "--fixture", fixture, "--rng-seed", "1", "--silent-audio"]))
        app.state.settings.wpm = 30  // short rounds
        app.state.guided = guided
        let model = ListeningModel(app: app, tone: tone ?? app.tone, haptics: app.haptics)
        return (model, app)
    }

    @Test func rightAnswerLogsAndReveals() async {
        let (m, app) = makeListening(fixture: "fresh")
        await m.appear()
        #expect(m.phase == .awaiting)
        let answer = m.answer
        await m.pick(answer)
        #expect(m.phase == .right || m.phase == .hold)
        #expect(m.revealedCode == Morse.code(for: answer))
        #expect(app.state.progress.record(answer, .listening).recent == [true])
        #expect(app.state.hasListened)
        m.disappear()
    }

    @Test func wrongAnswerLogsFalseAndRevealsAnswer() async {
        let (m, app) = makeListening(fixture: "fresh")
        await m.appear()
        let answer = m.answer
        let wrong = m.options.first { $0 != answer }!
        await m.pick(wrong)
        #expect(m.phase == .wrong(picked: wrong))
        #expect(app.state.progress.record(answer, .listening).recent == [false])
        #expect(m.revealedCode == Morse.code(for: answer))
        m.disappear()
    }

    @Test func choicesModeOffersMinFourIncludingAnswer() async {
        let (m, _) = makeListening(fixture: "fresh")
        await m.appear()
        #expect(Set(m.options) == ["K", "M"])
        #expect(m.answerMode == .choices)
        m.disappear()
        let (k, _) = makeListening(fixture: "tenUnlocked")
        #expect(k.answerMode == .keyboard)
        #expect(k.options.count == 4)
        #expect(k.options.contains(k.answer))
    }

    @Test func interruptionCancelsRoundWithoutLogging() async {
        let tone = InterruptingTone()
        let (m, app) = makeListening(fixture: "fresh", tone: tone)
        await m.appear()
        #expect(m.phase == .awaiting)
        #expect(m.status == "Sound was interrupted. Tap the lamp to hear it again.")
        let answer = m.answer
        await m.pick(answer)  // an answer to a sound never heard is not scored
        #expect(app.state.progress.record("K", .listening).total == 0)
        #expect(app.state.progress.record("M", .listening).total == 0)
        m.disappear()
    }

    @Test func guidedRoundShowsCodeAndIsNotLogged() async {
        let (m, app) = makeListening(fixture: "fresh", guided: GuidedRounds(drill: .listening, character: "R", remaining: 3))
        await m.appear()
        #expect(m.answer == "R")
        #expect(m.revealedCode == Morse.code(for: "R"))
        #expect(m.options.contains("R"))
        await m.pick("R")
        #expect(app.state.progress.record("R", .listening).total == 0)
        #expect(app.state.guided?.remaining == 2)
        m.disappear()
    }

    /// Answering while the character is still sounding counts: the learner chose to answer early.
    @Test func pickDuringPlaybackIsScoredAndKeepsItsResult() async {
        let (m, app) = makeListening(fixture: "fresh")
        app.state.settings.wpm = 5  // a long round
        let appearing = Task { await m.appear() }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(m.phase == .playing)
        let answer = m.answer
        await m.pick(answer)
        #expect(m.phase == .right)
        #expect(app.state.progress.record(answer, .listening).recent == [true])
        m.disappear()  // cancels the next round
        await appearing.value
        #expect(m.phase == .right)  // the finishing playback must not reset the decided round
    }

    @Test func firstRoundStatusAndUnlockFlag() async {
        let (m, _) = makeListening(fixture: "fresh")
        #expect(m.status == "Listen, then pick the letter")
        let (n, app) = makeListening(fixture: "aboutToUnlock")
        n.setAnswer("M")
        await n.appear()
        app.state.progress.log("M", .keying, correct: true, rule: UnlockPace.standard.rule)  // the set is now solid
        #expect(app.state.progress.pendingUnlock)
        await n.pick("M")
        #expect(n.revealPending == "R")
        n.disappear()
    }

    /// Lock the phone during the result hold: coming back starts a new round and never scores the old one twice.
    @Test func foregroundDuringTheHoldStartsANewRoundWithoutDoubleLogging() async {
        let (m, app) = makeListening(fixture: "fresh")
        await m.appear()
        let answer = m.answer
        await m.pick(answer)
        #expect(m.phase == .right)
        m.disappear()
        await m.appear()
        #expect(m.phase == .awaiting)
        #expect(m.answer != answer)
        #expect(m.revealedCode == nil)
        await m.pick(m.answer)
        #expect(app.state.progress.record(answer, .listening).total == 1)
        m.disappear()
    }

    /// Control Center or a banner: `.inactive` then `.active` with no background. Nothing replays and nothing is unscored.
    @Test func reappearWhileAwaitingReplaysOnlyOnce() async {
        let (m, _) = makeListening(fixture: "fresh")
        await m.appear()
        #expect(m.phase == .awaiting)
        await m.appear()
        #expect(m.phase == .awaiting)
        #expect(m.status != ListeningModel.interruptedStatus)
        m.disappear()
    }

    @Test func pendingUnlockAtEntryParksForTheReveal() async {
        let (first, app) = makeListening(fixture: "aboutToUnlock")
        app.state.progress.log("M", .keying, correct: true, rule: UnlockPace.standard.rule)
        #expect(app.state.progress.pendingUnlock)
        _ = first
        let m = ListeningModel(app: app, tone: app.tone, haptics: app.haptics)
        #expect(m.revealPending == "R")
        await m.appear()
        #expect(m.phase == .hold)
        #expect(m.revealReady == "R")
        m.disappear()
    }

    /// The keyingBehind shape: K and M seasoned in listening only, so listening more will not help.
    @Test func nudgeFiresAfterTheHoldOnce() async {
        let (first, app) = makeListening(fixture: "fresh")
        _ = first
        let rule = UnlockPace.standard.rule
        var progress = LearnerProgress.initial
        for _ in 0..<18 {
            progress.log("K", .listening, correct: true, rule: rule)
            progress.log("M", .listening, correct: true, rule: rule)
        }
        app.state.progress = progress
        app.state.hasListened = true
        let m = ListeningModel(app: app, tone: app.tone, haptics: app.haptics)
        m.setAnswer("M")
        await m.appear()
        await m.pick("M")
        #expect(m.nudgePending); #expect(!m.nudgeReady)
        #expect(app.state.nudges.isEmpty)  // not shown yet
        try? await Task.sleep(for: .milliseconds(1_300))
        #expect(m.phase == .hold)
        #expect(m.nudgeReady)
        #expect(app.state.nudges == [Nudge(drill: .listening, character: "M")])
        await m.resumeAfterNudge()
        #expect(!m.nudgePending)
        #expect(m.phase == .playing || m.phase == .awaiting)
        m.disappear()
    }

    /// A listening model over the keyingBehind shape (K and M seasoned in listening only), answer M.
    private func keyingBehind(guided: GuidedRounds? = nil) -> (ListeningModel, AppModel) {
        let (_, app) = makeListening(fixture: "fresh")
        let rule = UnlockPace.standard.rule
        var progress = LearnerProgress.initial
        for _ in 0..<18 {
            progress.log("K", .listening, correct: true, rule: rule)
            progress.log("M", .listening, correct: true, rule: rule)
        }
        app.state.progress = progress
        app.state.hasListened = true
        app.state.guided = guided
        let m = ListeningModel(app: app, tone: app.tone, haptics: app.haptics)
        m.setAnswer("M")
        return (m, app)
    }

    /// Only a correct answer arms the nudge: a logged miss on the nudge-due progress does not.
    @Test func nudgeIsNotArmedByAMiss() async {
        let (m, app) = keyingBehind()
        await m.appear()
        await m.pick("K")
        #expect(app.state.progress.record("M", .listening).recent.last == false)
        #expect(!m.nudgePending)
        m.disappear()
    }

    /// Guided rounds after a reveal are never interrupted by the nudge.
    @Test func nudgeNeverFiresInGuidedRounds() async {
        let (m, _) = keyingBehind(guided: GuidedRounds(drill: .listening, character: "M", remaining: 3))
        #expect(m.mode == .guided("M", remaining: 3))
        await m.appear()
        await m.pick("M")
        #expect(!m.nudgePending)
        m.disappear()
    }

    /// Leaving during the hold, before the sheet shows, keeps the nudge for the next visit.
    @Test func nudgeLeftDuringTheHoldIsNotSpent() async {
        let (m, app) = keyingBehind()
        await m.appear()
        await m.pick("M")
        #expect(m.nudgePending)
        m.disappear()
        #expect(app.state.nudges.isEmpty)
    }

    @Test func handOverKeepsToneRunning() {
        let tone = StopCountingTone()
        let (m, _) = makeListening(fixture: "fresh", tone: tone)
        m.handOver(); m.disappear()
        #expect(tone.stops == 0)
        let (plain, _) = makeListening(fixture: "fresh", tone: tone)
        plain.disappear()
        #expect(tone.stops == 1)
    }
}
