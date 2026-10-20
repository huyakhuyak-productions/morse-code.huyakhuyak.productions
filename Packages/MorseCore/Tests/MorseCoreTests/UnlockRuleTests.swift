import Testing
@testable import MorseCore

@Test func pacePresetsMatchSpec() {
    #expect(UnlockPace.relaxed.rule == UnlockRule(newestFloor: 5, setWindow: 20, setFloor: 10, accuracy: 0.85))
    #expect(UnlockPace.standard.rule == UnlockRule(newestFloor: 8, setWindow: 30, setFloor: 12, accuracy: 0.90))
    #expect(UnlockPace.strict.rule == UnlockRule(newestFloor: 20, setWindow: 50, setFloor: 20, accuracy: 0.90))
    #expect(UnlockPace.allCases == [.relaxed, .standard, .strict])
}

@Test func standardUnlocksAfterEightOnNewest() {
    let rule = UnlockPace.standard.rule
    var p = LearnerProgress.initial
    for _ in 0..<8 { for s in Skill.allCases { p.log("K", s, correct: true, rule: rule) } }
    for _ in 0..<7 { for s in Skill.allCases { p.log("M", s, correct: true, rule: rule) } }
    p.log("M", .keying, correct: true, rule: rule)
    #expect(!p.isSetSolid(rule))                       // M listening has 7
    p.log("M", .listening, correct: true, rule: rule)
    #expect(p.isSetSolid(rule))
    #expect(p.pendingUnlock)
    #expect(!p.isSetSolid(UnlockPace.strict.rule))     // same data, stricter rule
}

@Test func accuracyWindowFollowsTheRule() {
    let rule = UnlockPace.standard.rule
    var p = solidKM()                                   // 80 correct stored (last 50 kept)
    for _ in 0..<4 { p.log("K", .keying, correct: false, rule: rule) }   // last 30: 26/30 = 0.867
    #expect(!p.isSetSolid(rule))
    #expect(p.isSetSolid(UnlockPace.strict.rule))      // last 50: 46/50 = 0.92
    #expect(p.recentOutcomes(last: 30).count == 30)
}

@Test func refreshPendingUnlockSetsButNeverClears() {
    var p = solidKM()
    _ = p.unlockNext()
    #expect(!p.pendingUnlock)
    p.refreshPendingUnlock(rule: UnlockPace.standard.rule)
    #expect(!p.pendingUnlock)                           // R has no attempts
    var q = solidKM()                                   // pending already true
    q.refreshPendingUnlock(rule: UnlockPace.strict.rule)
    #expect(q.pendingUnlock)
}
