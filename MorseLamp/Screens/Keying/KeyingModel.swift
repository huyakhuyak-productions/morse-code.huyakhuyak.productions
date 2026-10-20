import MorseCore
import Observation
import SwiftUI

/// The keying drill: one target at a time, judged from paddle presses, logged into progress.
@MainActor @Observable
final class KeyingModel {
    enum Phase: Equatable {
        case keying
        case matched
        /// Wrong sequence (`fault == nil`) or, under strict timing, the right sequence with one element out of tolerance.
        case missed(fault: StrictTiming.Fault?)
        case hold
    }

    enum Mode: Equatable {
        case normal
        /// Ten prompts of one character from the home sheet; logged normally.
        case practice(Character, remaining: Int)
        /// The prompts after a reveal: the new character with its code shown; never logged.
        case guided(Character, remaining: Int)
    }

    static let practiceRounds = 10
    static let hold: Duration = .milliseconds(800)

    private(set) var target: Character
    private(set) var keyed: [Element] = []
    private(set) var presses: [Press] = []
    private(set) var phase: Phase = .keying
    private(set) var status = ""
    /// Shown small under the readout after a miss (until the next press) and throughout guided rounds.
    private(set) var hint: Code?
    private(set) var mode: Mode
    /// Set when a logged match makes the set solid; the view hands over to the reveal.
    var revealPending: Character?
    /// The pending reveal once the match's hold has run; the view presents it from here.
    var revealReady: Character? { phase == .keying ? revealPending : nil }
    private(set) var showsBluetoothNotice = false
    /// Increments on every miss; the view shakes the readout once per change.
    private(set) var shakeCount = 0
    private(set) var didFinishPractice = false

    var dit: TimeInterval { session.estimator.dit }

    @ObservationIgnored private let app: AppModel
    @ObservationIgnored let tone: any Tone
    @ObservationIgnored private let haptics: Haptics
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private var session: KeyingSession
    @ObservationIgnored private var hintedRetry = false
    @ObservationIgnored private var hasPressedThisVisit = false
    @ObservationIgnored private var holdTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    init(app: AppModel, tone: any Tone, haptics: Haptics, practice: Character? = nil, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.app = app
        self.tone = tone
        self.haptics = haptics
        self.now = now
        session = KeyingSession(estimator: app.state.estimator)
        if let practice {
            mode = .practice(practice, remaining: Self.practiceRounds)
            target = practice
        } else if let guided = app.state.guided, guided.drill == .keying, guided.remaining > 0 {
            mode = .guided(guided.character, remaining: guided.remaining)
            target = guided.character
            hint = Morse.code(for: guided.character)
        } else {
            mode = .normal
            if let first = app.launch.firstTarget, app.state.progress.unlocked.contains(first) {
                target = first
            } else {
                target = CharacterPicker.pick(from: app.state.progress, skill: .keying, avoiding: nil, rule: app.rule, using: &app.rng)
            }
            // The rule became true during practice, or the app closed mid-hold: the reveal fires on this prompt.
            if app.state.progress.pendingUnlock {
                revealPending = app.state.progress.next
            }
        }
        refreshStatus()
    }

    // MARK: Lifecycle

    func appear() async {
        hasPressedThisVisit = false
        haptics.isEnabled = app.state.settings.haptics
        await tone.start()
        tone.setPitch(app.state.settings.pitchHz)
        // Backgrounded during a result hold: the hold task is gone, so move on to the next prompt here.
        if phase != .keying {
            nextPrompt()
            return
        }
        refreshStatus()
        announce(String(target))
    }

    /// Leaving the drill or backgrounding: pending presses are dropped, never carried over.
    func disappear() {
        holdTask?.cancel()
        holdTask = nil
        tickTask?.cancel()
        tickTask = nil
        session.clear()
        keyed = []
        presses = []
        tone.keyUp()
        tone.stop()
        app.save()
    }

    // MARK: Paddle

    func keyDown(at t: TimeInterval) {
        guard phase == .keying else { return }
        hasPressedThisVisit = true
        if hintedRetry, case .guided = mode {} else if hintedRetry { hint = nil }
        session.keyDown(at: t)
        tone.keyDown()
        haptics.press()
        refreshStatus()
    }

    func keyUp(at t: TimeInterval) {
        guard session.isKeyDown else { return }
        _ = session.keyUp(at: t)
        keyed = session.elements
        presses = session.presses
        tone.keyUp()
        haptics.release()
        startTicking()
        refreshStatus()
    }

    /// Submits the pending character once the silence after the last release is long enough.
    func tick(now t: TimeInterval) {
        guard phase == .keying, let out = session.tick(now: t) else { return }
        submit(elements: out.elements, presses: out.presses)
    }

    private func startTicking() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
                guard let self else { return }
                self.tick(now: self.now())
                if self.keyed.isEmpty { break }
            }
            self?.tickTask = nil
        }
    }

    // MARK: Judgement

    private func submit(elements: [Element], presses: [Press]) {
        guard let code = Morse.code(for: target) else { return }
        app.state.hasKeyed = true
        keyed = elements
        self.presses = presses
        let sequenceMatches = elements == code.elements
        let fault = sequenceMatches && app.state.settings.strictTiming
            ? StrictTiming.firstFault(presses: presses, elements: elements, dit: session.estimator.dit)
            : nil
        var isGuided = false
        if case .guided = mode { isGuided = true }
        let shouldLog = !hintedRetry && !isGuided

        if sequenceMatches, fault == nil {
            phase = .matched
            status = "\(target)  \(code.display)"
            session.estimator.learn(presses: presses, elements: elements)
            app.state.estimator = session.estimator
            if shouldLog {
                app.state.progress.log(target, .keying, correct: true, rule: app.rule)
                if app.state.progress.pendingUnlock, mode == .normal {
                    revealPending = app.state.progress.next
                }
            }
            hintedRetry = false
            announce("\(target), matched")
        } else if sequenceMatches, let fault {
            phase = .missed(fault: fault)
            let element = fault.element == .dash ? "Dash" : "Dot"
            let problem = fault.problem == .tooShort ? "short" : "long"
            status = "Right pattern. \(element) \(fault.ordinal) was too \(problem)."
            if shouldLog { app.state.progress.log(target, .keying, correct: false, rule: app.rule) }
            hintedRetry = true
            announce(status)
        } else {
            phase = .missed(fault: nil)
            hint = code
            status = "\(target) is \(code.display)"
            shakeCount += 1
            if shouldLog { app.state.progress.log(target, .keying, correct: false, rule: app.rule) }
            hintedRetry = true
            announce("Missed. \(status)")
        }
        advanceMode()
        app.save()
        scheduleHold()
    }

    private func advanceMode() {
        switch mode {
        case .normal:
            break
        case .practice(let character, let remaining):
            // The last result is shown through its hold like any other; `nextPrompt` ends the practice.
            mode = .practice(character, remaining: remaining - 1)
        case .guided(let character, let remaining):
            let left = remaining - 1
            if left > 0 {
                mode = .guided(character, remaining: left)
                app.state.guided = GuidedRounds(drill: .keying, character: character, remaining: left)
            } else {
                mode = .normal
                app.state.guided = nil
            }
        }
    }

    private func scheduleHold() {
        holdTask?.cancel()
        holdTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hold)
            guard !Task.isCancelled else { return }
            self?.nextPrompt()
        }
    }

    // MARK: Prompts

    /// Clears the readout and asks the next character: the same one after a miss, the practice or
    /// guided character in those modes, otherwise a weighted pick that avoids an immediate repeat.
    func nextPrompt() {
        holdTask?.cancel()
        holdTask = nil
        session.clear()
        keyed = []
        presses = []
        phase = .keying
        switch mode {
        case .practice(let character, let remaining):
            if remaining <= 0 {
                didFinishPractice = true
                return
            }
            target = character
            if !hintedRetry { hint = nil }
        case .guided(let character, _):
            target = character
            hint = Morse.code(for: character)
        case .normal:
            if hintedRetry || revealPending != nil {
                // Same target: a hinted retry keeps its hint; a pending reveal takes over from here.
            } else {
                target = CharacterPicker.pick(from: app.state.progress, skill: .keying, avoiding: target, rule: app.rule, using: &app.rng)
                hint = nil
            }
        }
        // After a miss the status, like the hint, stays until the next press.
        if !hintedRetry { refreshStatus() }
        announce(String(target))
    }

    /// After the reveal: the guided rounds "Keep going" scheduled, or the normal rotation if none.
    func resumeAfterReveal() {
        revealPending = nil
        hintedRetry = false
        if let guided = app.state.guided, guided.drill == .keying, guided.remaining > 0 {
            mode = .guided(guided.character, remaining: guided.remaining)
        } else {
            mode = .normal
        }
        nextPrompt()
    }

    /// Test seam: force the next target.
    func setTarget(_ character: Character) {
        holdTask?.cancel()
        session.clear()
        keyed = []
        presses = []
        phase = .keying
        hint = nil
        hintedRetry = false
        target = character
        refreshStatus()
    }

    func refreshStatus() {
        guard phase == .keying else { return }
        if !keyed.isEmpty {
            status = Code(elements: keyed).display
        } else if !app.state.hasKeyed {
            status = "Tap for a dot, hold for a dash"
        } else if app.lamp.isMuted, !hasPressedThisVisit {
            status = "Sound is off"
        } else if app.lamp.routeIsBluetooth, !hasPressedThisVisit, showsBluetoothNotice || !app.state.bluetoothNoticeShown {
            status = "Headphones over Bluetooth add delay to the key"
            showsBluetoothNotice = true
            app.state.bluetoothNoticeShown = true
        } else {
            status = ""
        }
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
