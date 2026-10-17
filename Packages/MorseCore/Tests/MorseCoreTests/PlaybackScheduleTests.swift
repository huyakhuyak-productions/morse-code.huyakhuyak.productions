import Testing
@testable import MorseCore

private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

@Test func unitIs1200OverWpm() {
    #expect(near(PlaybackSchedule.unit(wpm: 15), 0.08))
    #expect(near(PlaybackSchedule.unit(wpm: 20), 0.06))
}

@Test func kAtFifteenWpm() {
    let s = PlaybackSchedule(code: Morse.code(for: "K")!, wpm: 15)
    #expect(zip(s.segments.map(\.start), [0, 0.32, 0.48]).allSatisfy(near))
    #expect(zip(s.segments.map(\.end), [0.24, 0.40, 0.72]).allSatisfy(near))
    #expect(s.segments.map(\.elementIndex) == [0, 1, 2])
    #expect(near(s.duration, 0.72))
}

@Test func elementIndexLookup() {
    let s = PlaybackSchedule(code: Morse.code(for: "K")!, wpm: 15)
    #expect(s.elementIndex(at: 0.1) == 0)
    #expect(s.elementIndex(at: 0.28) == nil)   // gap
    #expect(s.elementIndex(at: 0.5) == 2)
    #expect(s.elementIndex(at: 0.8) == nil)
}
