import Testing
@testable import MorseCore

@Test func keysASequence() {
    var s = KeyingSession(estimator: DitEstimator(dit: 0.1))
    s.keyDown(at: 0)
    #expect(s.keyUp(at: 0.3) == .dash)
    s.keyDown(at: 0.4)
    #expect(s.keyUp(at: 0.5) == .dot)
    #expect(s.elements == [.dash, .dot])
    #expect(s.tick(now: 0.9) == nil)                 // 0.4 s of silence < 0.6
    let out = s.tick(now: 1.11)
    #expect(out?.elements == [.dash, .dot])
    #expect(out?.presses == [Press(down: 0, up: 0.3), Press(down: 0.4, up: 0.5)])
    #expect(s.elements.isEmpty && s.presses.isEmpty)
}

@Test func doesNotSubmitWhileKeyIsDown() {         // Review Focus 1
    var s = KeyingSession(estimator: DitEstimator(dit: 0.1))
    s.keyDown(at: 0)
    _ = s.keyUp(at: 0.1)
    s.keyDown(at: 0.2)
    #expect(s.tick(now: 5.0) == nil)
    #expect(s.isKeyDown)
}

@Test func tickWithNothingPendingIsNil() {
    var s = KeyingSession(estimator: DitEstimator())
    #expect(s.tick(now: 10) == nil)
}

@Test func keyUpWithoutDownIsIgnored() {
    var s = KeyingSession(estimator: DitEstimator())
    #expect(s.keyUp(at: 1) == nil)
    #expect(s.elements.isEmpty)
}

@Test func clearDropsPendingAndKeyState() {
    var s = KeyingSession(estimator: DitEstimator(dit: 0.1))
    s.keyDown(at: 0)
    _ = s.keyUp(at: 0.1)
    s.keyDown(at: 0.2)
    s.clear()
    #expect(s.elements.isEmpty && s.presses.isEmpty && !s.isKeyDown)
    #expect(s.tick(now: 9) == nil)
}
