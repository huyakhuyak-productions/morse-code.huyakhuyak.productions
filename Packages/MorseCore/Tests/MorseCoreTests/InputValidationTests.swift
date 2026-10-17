import Testing
@testable import MorseCore

@Test func secondFingerDoesNotRestartThePress() {
    var s = KeyingSession(estimator: DitEstimator(dit: 0.1))
    s.keyDown(at: 0)
    s.keyDown(at: 0.3)                                // second finger lands
    #expect(s.keyUp(at: 0.35) == .dash)               // 350 ms from the first touch, not 50 ms
    #expect(s.presses == [Press(down: 0, up: 0.35)])
}

@Test func pressNeverHasNegativeDuration() {
    let p = Press(down: 1.0, up: 0.5)
    #expect(p.duration == 0)
    #expect(p.up == 1.0)
}

@Test func learnIgnoresZeroLengthSamples() {
    var e = DitEstimator(dit: 0.1)
    e.learn(presses: [Press(down: 1.0, up: 0.5)], elements: [.dot])
    #expect(abs(e.dit - 0.1) < 1e-9)
}

@Test func learnUsesOneThresholdPerCharacter() {
    // dit 0.1. The dash (0.15 s → sample 0.05) pulls dit down to 0.085 first. If the 1.5× dot
    // threshold followed that update it would be 0.1275 and reject the 0.14 s dot; the threshold
    // is fixed at 0.15 for the whole character, so the dot is folded in: 0.7·0.085 + 0.3·0.14.
    var e = DitEstimator(dit: 0.1)
    e.learn(presses: [Press(down: 0, up: 0.15), Press(down: 0.3, up: 0.44)], elements: [.dash, .dot])
    #expect(abs(e.dit - 0.1015) < 1e-9)
}

@Test func playbackScheduleClampsWordsPerMinute() {
    let zero = PlaybackSchedule(code: Morse.code(for: "E")!, wpm: 0)
    #expect(zero.unit.isFinite && zero.duration.isFinite)
    #expect(zero.elementIndex(at: 1_000) == nil)
    #expect(PlaybackSchedule.unit(wpm: -5) == PlaybackSchedule.unit(wpm: 1))
}
