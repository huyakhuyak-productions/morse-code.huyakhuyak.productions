import Testing
@testable import MorseCore

@Test func logIgnoresCharactersOutsideTheUnlockedSet() {
    var p = LearnerProgress.initial
    p.log("R", .keying, correct: true, rule: UnlockPace.strict.rule)        // locked
    p.log("k", .keying, correct: true, rule: UnlockPace.strict.rule)        // not a character in the table
    #expect(!p.hasLoggedAttempts)
    #expect(p.record("R", .keying).total == 0)
}

@Test func completeSentenceWinsOverFirstRun() {
    var p = LearnerProgress.initial
    for _ in 0..<34 { _ = p.unlockNext() }    // everything unlocked, nothing logged
    let s = HomeSummary(progress: p, rule: UnlockPace.standard.rule)
    #expect(s.kind == .complete)
    #expect(s.plainText == "All 36 unlocked, 0 mastered.")
}

