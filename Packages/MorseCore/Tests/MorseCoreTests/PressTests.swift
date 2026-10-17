import Testing
@testable import MorseCore

@Test func classifyAgainstTwiceDit() {
    let e = DitEstimator()   // 0.110
    #expect(e.classify(Press(down: 0, up: 0.219)) == .dot)
    #expect(e.classify(Press(down: 0, up: 0.220)) == .dash)
}

@Test func submitGapHasFloor() {
    #expect(abs(DitEstimator(dit: 0.1).submitGap - 0.6) < 1e-9)
    #expect(abs(DitEstimator(dit: 0.2).submitGap - 0.8) < 1e-9)
}

@Test func learnFoldsDotsAndThirdOfDashes() {
    var e = DitEstimator(dit: 0.1)
    e.learn(presses: [Press(down: 0, up: 0.3)], elements: [.dash])         // sample 0.1, unchanged
    #expect(abs(e.dit - 0.1) < 1e-9)
    e.learn(presses: [Press(down: 0, up: 0.08)], elements: [.dot])         // 0.7·0.1 + 0.3·0.08
    #expect(abs(e.dit - 0.094) < 1e-9)
}

@Test func learnIgnoresLongDotsAndClamps() {
    var e = DitEstimator(dit: 0.1)
    e.learn(presses: [Press(down: 0, up: 0.16)], elements: [.dot])         // ≥ 1.5·dit, ignored
    #expect(abs(e.dit - 0.1) < 1e-9)
    var low = DitEstimator(dit: 0.062)
    for _ in 0..<20 { low.learn(presses: [Press(down: 0, up: 0.02)], elements: [.dot]) }
    #expect(low.dit == DitEstimator.minimum)
    var high = DitEstimator(dit: 0.24)
    for _ in 0..<20 { high.learn(presses: [Press(down: 0, up: 1.5)], elements: [.dash]) }
    #expect(high.dit == DitEstimator.maximum)
}

@Test func strictFindsFirstFaultByOrdinal() {
    // K at dit 0.1: dash 3.0u ok, dot 1.0u ok, dash 2.0u < 2.2 → too short, ordinal 3
    let presses = [Press(down: 0, up: 0.3), Press(down: 0.4, up: 0.5), Press(down: 0.6, up: 0.8)]
    let f = StrictTiming.firstFault(presses: presses, elements: [.dash, .dot, .dash], dit: 0.1)
    #expect(f == StrictTiming.Fault(ordinal: 3, element: .dash, problem: .tooShort))
}

@Test func strictReportsTooLong() {
    let presses = [Press(down: 0, up: 0.17), Press(down: 0.3, up: 0.6)]   // dot 1.7u > 1.6
    let f = StrictTiming.firstFault(presses: presses, elements: [.dot, .dash], dit: 0.1)
    #expect(f == StrictTiming.Fault(ordinal: 1, element: .dot, problem: .tooLong))
}

@Test func strictAcceptsWithinTolerance() {
    let presses = [Press(down: 0, up: 0.45), Press(down: 0.5, up: 0.66), Press(down: 0.7, up: 0.92)]  // 4.5u, 1.6u, 2.2u
    #expect(StrictTiming.firstFault(presses: presses, elements: [.dash, .dot, .dash], dit: 0.1) == nil)
}
