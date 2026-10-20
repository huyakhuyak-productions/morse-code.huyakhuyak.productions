import Foundation
import Testing
@testable import MorseCore

@Test func initialState() {
    let p = LearnerProgress.initial
    #expect(p.unlocked == ["K", "M"])
    #expect(p.next == "R")
    #expect(p.newest == "M")
    #expect(p.locked.count == 34)
    #expect(p.level(of: "K") == .new)
    #expect(!p.isSetSolid(UnlockPace.strict.rule))
    #expect(!p.pendingUnlock)
}

@Test func levelThresholds() {
    #expect(Level(accuracy: 1.0, attempts: 4) == .new)
    #expect(Level(accuracy: 0.9, attempts: 5) == .mastered)
    #expect(Level(accuracy: 0.89, attempts: 20) == .nearly)
    #expect(Level(accuracy: 0.7, attempts: 20) == .nearly)
    #expect(Level(accuracy: 0.4, attempts: 20) == .learning)
    #expect(Level(accuracy: 0.39, attempts: 20) == .new)
    #expect(Level(accuracy: nil, attempts: 0) == .new)
}

@Test func recentWindowIsTwenty() {
    var p = LearnerProgress.initial
    for _ in 0..<25 { p.log("K", .keying, correct: false, rule: UnlockPace.strict.rule) }
    for _ in 0..<20 { p.log("K", .keying, correct: true, rule: UnlockPace.strict.rule) }
    #expect(p.record("K", .keying).recent.count == 20)
    #expect(p.record("K", .keying).total == 45)
    #expect(p.record("K", .keying).correctRecent == 20)
    #expect(p.level(of: "K", in: .keying) == .mastered)
    #expect(p.level(of: "K") == .new)             // listening still new
}

@Test func setIsNotSolidBelowTwentyAttempts() {    // Review Focus 2
    var p = LearnerProgress.initial
    for _ in 0..<6 { p.log("K", .keying, correct: true, rule: UnlockPace.strict.rule); p.log("M", .keying, correct: true, rule: UnlockPace.strict.rule) }
    #expect(!p.isSetSolid(UnlockPace.strict.rule))
}

@Test func unlockRuleNeedsBothSkillsAndTwentyOnNewest() {
    var p = LearnerProgress.initial
    for _ in 0..<20 { p.log("K", .keying, correct: true, rule: UnlockPace.strict.rule); p.log("M", .keying, correct: true, rule: UnlockPace.strict.rule) }
    #expect(!p.isSetSolid(UnlockPace.strict.rule))                          // listening is still "new"
    for _ in 0..<19 { p.log("K", .listening, correct: true, rule: UnlockPace.strict.rule); p.log("M", .listening, correct: true, rule: UnlockPace.strict.rule) }
    #expect(!p.isSetSolid(UnlockPace.strict.rule))                          // newest (M) has 19 listening attempts
    p.log("K", .listening, correct: true, rule: UnlockPace.strict.rule)
    #expect(!p.isSetSolid(UnlockPace.strict.rule))
    p.log("M", .listening, correct: true, rule: UnlockPace.strict.rule)
    #expect(p.isSetSolid(UnlockPace.strict.rule))
    #expect(p.pendingUnlock)
    #expect(p.unlockNext() == "R")
    #expect(p.unlockedCount == 3)
    #expect(!p.pendingUnlock)
}

@Test func setAccuracyUsesLastFiftyAcrossSkills() {
    var p = solidKM()                               // 80 correct logged
    for _ in 0..<6 { p.log("K", .keying, correct: false, rule: UnlockPace.strict.rule) }   // last 50: 44 correct → 0.88
    #expect(!p.isSetSolid(UnlockPace.strict.rule))
}

@Test func unlockNextClearsPending() {
    var p = solidKM()
    #expect(p.pendingUnlock)
    _ = p.unlockNext()
    #expect(!p.pendingUnlock)
    p.log("K", .keying, correct: false, rule: UnlockPace.strict.rule)             // an incorrect answer never sets it
    #expect(!p.pendingUnlock)
}

@Test func pendingUnlockStaysWhileCompleteIsFalseOnly() {
    var p = LearnerProgress.initial
    for _ in 0..<34 { _ = p.unlockNext() }
    p.log("K", .keying, correct: true, rule: UnlockPace.strict.rule)
    #expect(!p.pendingUnlock)                       // nothing left to unlock
}

@Test func slippingExcludesTwoNewest() {
    var p = solidKM()
    _ = p.unlockNext(); _ = p.unlockNext()          // K M R S; newest two: R, S
    for _ in 0..<20 { p.log("K", .keying, correct: false, rule: UnlockPace.strict.rule) }
    #expect(p.slipping == ["K"])
    #expect(p.masteredCount == 1)                   // M
}

@Test func slippingIgnoresUntrainedCharacters() {
    var p = solidKM()
    for _ in 0..<5 { _ = p.unlockNext() }           // R S U A P unlocked with no attempts
    #expect(p.slipping.isEmpty)
    for _ in 0..<4 { p.log("R", .keying, correct: false, rule: UnlockPace.strict.rule); p.log("R", .listening, correct: false, rule: UnlockPace.strict.rule) }
    #expect(p.slipping.isEmpty)                     // 4 attempts: still not a measurement
    p.log("R", .keying, correct: false, rule: UnlockPace.strict.rule); p.log("R", .listening, correct: false, rule: UnlockPace.strict.rule)
    #expect(p.slipping == ["R"])
}

@Test func unlockNextReturnsNilWhenComplete() {    // Review Focus 3
    var p = LearnerProgress.initial
    for _ in 0..<34 { _ = p.unlockNext() }
    #expect(p.isComplete)
    #expect(p.next == nil)
    #expect(p.unlockNext() == nil)
    #expect(p.unlockedCount == 36)
    #expect(p.newest == "4")
}

@Test func resetKeepsOnlyKAndM() {
    var p = solidKM()
    _ = p.unlockNext()
    p.reset()
    #expect(p == LearnerProgress.initial)
}

@Test func roundTripsThroughJSON() throws {
    let p = solidKM()
    let data = try JSONEncoder().encode(p)
    #expect(try JSONDecoder().decode(LearnerProgress.self, from: data) == p)
}
