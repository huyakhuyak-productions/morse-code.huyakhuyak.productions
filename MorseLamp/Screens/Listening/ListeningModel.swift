import MorseCore
import Observation
import SwiftUI

/// The listening drill: a character plays, the learner names it.
@MainActor @Observable
final class ListeningModel {
    enum Phase: Equatable {
        case playing
        case awaiting
        case right
        case wrong(picked: Character)
        case hold
    }

    enum Mode: Equatable {
        case normal
        /// The rounds after a reveal: the new character with its code shown and highlighted; never logged.
        case guided(Character, remaining: Int)
    }

    static let hold: Duration = .milliseconds(1_100)
    static let interruptedStatus = "Sound was interrupted. Tap the lamp to hear it again."

    private(set) var answer: Character
    /// Choices mode: `min(4, unlocked)` buttons that always include the answer.
    private(set) var options: [Character] = []
    private(set) var phase: Phase = .playing
    private(set) var status = ""
    /// Shown beneath the lamp after answering, and before answering in guided rounds.
    private(set) var revealedCode: Code?
    private(set) var mode: Mode
    var revealPending: Character?
    /// The pending reveal once the answer's hold has run; the view presents it from here.
    var revealReady: Character? { phase == .hold ? revealPending : nil }
    /// Set by a logged answer when the other drill is what holds the next letter back.
    private(set) var nudgePending = false
    /// The pending nudge once the answer's hold has run and no reveal is due; the view presents it from here.
    var nudgeReady: Bool { phase == .hold && nudgePending && revealPending == nil }
    private(set) var answerMode: AnswerMode

    @ObservationIgnored private let app: AppModel
    @ObservationIgnored let tone: any Tone
    @ObservationIgnored private let haptics: Haptics
    /// The current round's sound was heard in full; an answer to an unheard round is never scored.
    @ObservationIgnored private var heardRound = false
    @ObservationIgnored private var roundTask: Task<Void, Never>?
    /// Bumped by every new round, so playback that finishes late cannot touch a later round.
    @ObservationIgnored private var roundID = 0
    /// The first `appear()` plays the prepared round; a later one during `.playing` leaves the sound alone.
    @ObservationIgnored private var isFirstPlay = true
    /// The nudge is handing over to the keying drill, which keeps the shared engine running.
    @ObservationIgnored private var isHandingOver = false
    /// The pending nudge has been stored as shown; it is stored once, when it becomes ready.
    @ObservationIgnored private var nudgeRecorded = false

    init(app: AppModel, tone: any Tone, haptics: Haptics) {
        self.app = app
        self.tone = tone
        self.haptics = haptics
        answerMode = app.resolvedAnswerMode()
        if let guided = app.state.guided, guided.drill == .listening, guided.remaining > 0 {
            mode = .guided(guided.character, remaining: guided.remaining)
            answer = guided.character
        } else {
            mode = .normal
            if let first = app.launch.firstTarget, app.state.progress.unlocked.contains(first) {
                answer = first
            } else {
                answer = CharacterPicker.pick(from: app.state.progress, skill: .listening, avoiding: nil, rule: app.rule, using: &app.rng)
            }
            // The rule became true during practice, or the app closed mid-hold: the reveal comes before any round.
            if app.state.progress.pendingUnlock {
                revealPending = app.state.progress.next
            }
        }
        prepareRound()
    }

    func isEnabled(_ character: Character) -> Bool {
        app.state.progress.unlocked.contains(character)
    }

    // MARK: Lifecycle

    /// First entry plays the round. Returning from the background resumes by phase: a finished
    /// round moves on, an awaiting round replays, a sounding round is left to finish, and a pending
    /// reveal or nudge parks the drill until the view hands over.
    func appear() async {
        haptics.isEnabled = app.state.settings.haptics
        await tone.start()
        tone.setPitch(app.state.settings.pitchHz)
        if revealPending != nil || nudgePending {
            parkInHold()
            return
        }
        switch phase {
        case .right, .wrong, .hold:
            nextRound()
            await playRound()
        case .awaiting:
            await playRound()
        case .playing:
            // The first entry plays the prepared round. Later, a sounding round is left to finish:
            // if the background cut it, `playRound` already parked it as unheard and awaiting.
            guard isFirstPlay else { return }
            isFirstPlay = false
            await playRound()
        }
    }

    func disappear() {
        roundTask?.cancel()
        roundTask = nil
        if !isHandingOver { tone.stop() }
        app.save()
    }

    /// The learner took the nudge: the next `disappear()` leaves the engine to the keying drill.
    func handOver() {
        isHandingOver = true
    }

    /// Clears the nudge without starting a round; used when the drill is leaving.
    func dismissNudge() {
        nudgePending = false
        nudgeRecorded = false
    }

    // MARK: Rounds

    /// Plays the answer. A cut-off sound leaves the round unscored until the lamp replays it.
    func playRound() async {
        phase = .playing
        let round = roundID
        let heard = await tone.play(PlaybackSchedule(code: code, wpm: app.state.settings.wpm))
        // An early answer may already have decided this round, or a later round may have begun.
        guard !Task.isCancelled, round == roundID, phase == .playing else { return }
        heardRound = heard
        if !heard {
            status = Self.interruptedStatus
        } else if status == Self.interruptedStatus {
            refreshStatus()
        }
        phase = .awaiting
    }

    func replay() async {
        guard phase == .awaiting else { return }
        await playRound()
    }

    /// Answers the round. Allowed while the character is still sounding: answering early is the
    /// learner's choice, so that round counts as heard.
    func pick(_ picked: Character) async {
        guard phase == .awaiting || phase == .playing else { return }
        if phase == .playing { heardRound = true }
        app.state.hasListened = true
        let correct = picked == answer
        var isGuided = false
        if case .guided = mode { isGuided = true }
        let shouldLog = heardRound && !isGuided
        revealedCode = code
        if correct {
            phase = .right
            status = "\(answer)  \(code.display)"
            if shouldLog {
                app.state.progress.log(answer, .listening, correct: true, rule: app.rule)
                if app.state.progress.pendingUnlock, mode == .normal {
                    revealPending = app.state.progress.next
                }
                // Only a correct answer arms the nudge: a miss never ends on a sheet.
                if mode == .normal, revealPending == nil {
                    nudgePending = app.isNudgeDue(in: .listening)
                }
            }
            announce("\(answer), right")
        } else {
            phase = .wrong(picked: picked)
            status = "It was \(answer), not \(picked)."
            if shouldLog { app.state.progress.log(answer, .listening, correct: false, rule: app.rule) }
            announce(status)
        }
        advanceMode()
        app.save()
        let wasWrong = !correct
        roundTask?.cancel()
        roundTask = Task { [weak self] in
            guard let self else { return }
            if wasWrong {
                // The code replays once with the answer revealed.
                _ = await self.tone.play(PlaybackSchedule(code: self.code, wpm: self.app.state.settings.wpm))
                try? await Task.sleep(for: .milliseconds(400))
            } else {
                try? await Task.sleep(for: Self.hold)
            }
            guard !Task.isCancelled else { return }
            if self.revealPending != nil || self.nudgePending {
                // The hold is over; the view hands over to the reveal or the nudge.
                self.parkInHold()
                return
            }
            self.nextRound()
            await self.playRound()
        }
    }

    /// After the reveal: the guided rounds "Keep going" scheduled, or the normal rotation if none.
    func resumeAfterReveal() async {
        revealPending = nil
        roundTask?.cancel()
        roundTask = nil
        if let guided = app.state.guided, guided.drill == .listening, guided.remaining > 0 {
            mode = .guided(guided.character, remaining: guided.remaining)
        } else {
            mode = .normal
        }
        nextRound()
        await playRound()
    }

    /// Parks the drill for the view to present the reveal or the nudge. A nudge counts as shown
    /// from here, never earlier, so leaving during the hold keeps it for the next visit.
    private func parkInHold() {
        phase = .hold
        if nudgePending, revealPending == nil, !nudgeRecorded {
            app.recordNudge(in: .listening)
            nudgeRecorded = true
        }
    }

    /// "Keep listening": the nudge closed, the next round plays.
    func resumeAfterNudge() async {
        dismissNudge()
        roundTask?.cancel()
        roundTask = nil
        nextRound()
        await playRound()
    }

    /// Test seam: force the answer for the round about to play.
    func setAnswer(_ character: Character) {
        answer = character
        prepareRound()
    }

    private func nextRound() {
        switch mode {
        case .guided(let character, _):
            answer = character
        case .normal:
            answer = CharacterPicker.pick(from: app.state.progress, skill: .listening, avoiding: answer, rule: app.rule, using: &app.rng)
        }
        prepareRound()
    }

    private func prepareRound() {
        roundID += 1
        heardRound = false
        options = CharacterPicker.choices(answer: answer, progress: app.state.progress, using: &app.rng)
        if case .guided = mode {
            if !options.contains(answer) { options = [answer] + options.dropLast() }
            revealedCode = code
        } else {
            revealedCode = nil
        }
        phase = .playing
        refreshStatus()
    }

    private func advanceMode() {
        guard case .guided(let character, let remaining) = mode else { return }
        let left = remaining - 1
        if left > 0 {
            mode = .guided(character, remaining: left)
            app.state.guided = GuidedRounds(drill: .listening, character: character, remaining: left)
        } else {
            mode = .normal
            app.state.guided = nil
        }
    }

    private func refreshStatus() {
        if !app.state.hasListened {
            status = "Listen, then pick the letter"
        } else if app.lamp.isMuted {
            status = "Sound is off"
        } else {
            status = ""
        }
    }

    private var code: Code {
        Morse.code(for: answer) ?? Code(elements: [])
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
