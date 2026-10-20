import Testing
@testable import MorseCore

private let rule = UnlockPace.standard.rule
private func listeningBehind() -> LearnerProgress {   // 18 correct K and M keying, no listening
    var p = LearnerProgress.initial
    for _ in 0..<18 { p.log("K", .keying, correct: true, rule: rule); p.log("M", .keying, correct: true, rule: rule) }
    return p
}

@Test func freshOutlookIsEmptyAndPointsAtListening() {
    let o = UnlockOutlook(progress: .initial, rule: rule)
    #expect(o.fraction == 0); #expect(o.percent == 0); #expect(o.advice == .listenMore("M"))   // tie → listening
}

@Test func listeningBehindIsTwoThirdsThere() {
    let o = UnlockOutlook(progress: listeningBehind(), rule: rule)
    #expect(abs(o.fraction - 2.0 / 3.0) < 0.001)     // seasoning 0.5, readiness 0.5, accuracy 1
    #expect(o.percent == 60)
    #expect(UnlockOutlook.percent(of: 0.99) == 90)
    #expect(o.advice == .listenMore("M"))
    #expect(UnlockOutlook.suggestsSwitching(from: .keying, progress: listeningBehind(), rule: rule))
    #expect(!UnlockOutlook.suggestsSwitching(from: .listening, progress: listeningBehind(), rule: rule))
}

@Test func keyingBehindMirrors() {
    var p = LearnerProgress.initial
    for _ in 0..<18 { p.log("K", .listening, correct: true, rule: rule); p.log("M", .listening, correct: true, rule: rule) }
    #expect(UnlockOutlook(progress: p, rule: rule).advice == .keyMore("M"))
}

@Test func solidSetIsFullAndAlmost() {
    let o = UnlockOutlook(progress: solidKM(), rule: rule)
    #expect(o.fraction == 1); #expect(o.percent == 100); #expect(o.advice == .almost)
}

@Test func outlookDropsAfterUnlock() {                   // Review Focus 3
    var p = solidKM(); _ = p.unlockNext()
    let o = UnlockOutlook(progress: p, rule: rule)
    #expect(o.fraction < 0.6)                            // (0 + 4/6 + 1) / 3 ≈ 0.556
    #expect(o.percent == 50)
    #expect(o.advice == .listenMore("R"))
}

@Test func newestUnderFloorBeatsAWeakOlderLetter() {
    var p = solidKM(); _ = p.unlockNext()               // R
    for _ in 0..<8 { p.log("R", .listening, correct: true, rule: rule) }
    for _ in 0..<5 { p.log("R", .keying, correct: true, rule: rule) }
    for _ in 0..<10 { p.log("K", .listening, correct: false, rule: rule) }   // K listening 10/20 → learning
    #expect(UnlockOutlook(progress: p, rule: rule).advice == .keyMore("R"))
}

@Test func lettersWeakInBothSkillsAreSteady() {
    var p = unflaggedSolidKM()
    for _ in 0..<10 { for s in Skill.allCases { p.log("K", s, correct: false, rule: rule) } }
    #expect(UnlockOutlook(progress: p, rule: rule).advice == .steady(["K"]))
}

@Test func accuracyAloneIsSteadyEmptyUntilAlmost() {
    var p = unflaggedSolidKM()
    for c: Character in ["K", "M"] { for s in Skill.allCases { for _ in 0..<3 { p.log(c, s, correct: false, rule: rule) } } }
    let o = UnlockOutlook(progress: p, rule: rule)       // every pair 17/20 nearly; window 18/27
    #expect(o.advice == .steady([])); #expect(o.fraction < 0.9)
    var q = unflaggedSolidKM()
    for _ in 0..<4 { q.log("M", .keying, correct: false, rule: rule) }   // window 26/27 → 0.988
    #expect(UnlockOutlook(progress: q, rule: rule).advice == .almost)
    #expect(UnlockOutlook(progress: q, rule: rule).fraction <= 0.99)
}

@Test func completeSetIsComplete() {
    var p = solidKM(); for _ in 0..<34 { _ = p.unlockNext() }
    let o = UnlockOutlook(progress: p, rule: rule)
    #expect(o.advice == .complete); #expect(o.fraction == 1)
    #expect(!UnlockOutlook.suggestsSwitching(from: .keying, progress: p, rule: rule))
}

/// Five correct K and M in both skills under the relaxed pace: the rule held, the reveal has not run.
func pendingUnderRelaxed() -> LearnerProgress {
    var p = LearnerProgress.initial
    let relaxed = UnlockPace.relaxed.rule
    for _ in 0..<5 { for c: Character in ["K", "M"] { for s in Skill.allCases { p.log(c, s, correct: true, rule: relaxed) } } }
    return p
}

@Test func pendingUnlockIsFullAndAlmostUnderAStricterPace() {
    let p = pendingUnderRelaxed()
    #expect(p.pendingUnlock)
    let strict = UnlockPace.strict.rule
    let o = UnlockOutlook(progress: p, rule: strict)
    #expect(o.fraction == 1); #expect(o.advice == .almost); #expect(o.percent == 100)
    #expect(!UnlockOutlook.suggestsSwitching(from: .keying, progress: p, rule: strict))
}

@Test func percentFloorsToTensWithoutLosingAnExactTenth() {
    #expect(UnlockOutlook.percent(of: (0.4 + 1.0 + 1.0) / 3) == 80)
    #expect(UnlockOutlook.percent(of: 0.99) == 90)
    #expect(UnlockOutlook.percent(of: 1) == 100)
    #expect(UnlockOutlook.percent(of: 0) == 0)
}

@Test func percentLabelReadsTensAndHidesZero() {
    #expect(UnlockOutlook.percentLabel(of: 0) == nil)
    #expect(UnlockOutlook.percentLabel(of: 0.99) == "90% there")
    #expect(UnlockOutlook.percentLabel(of: 1) == "100% there")
}
