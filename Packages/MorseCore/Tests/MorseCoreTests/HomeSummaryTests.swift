import Testing
@testable import MorseCore

@Test func firstRunSentence() {
    let s = HomeSummary(progress: .initial, rule: UnlockPace.standard.rule)
    #expect(s.kind == .firstRun)
    #expect(s.plainText == "Start with K and M. Key and listen to them until they stick, and R unlocks.")
    #expect(s.runs.filter(\.isBold).map(\.text) == ["K", "M"])
}

@Test func normalSentence() {
    var p = solidKM()
    for _ in 0..<5 { _ = p.unlockNext() }           // 7 unlocked, K and M mastered
    let s = HomeSummary(progress: p, rule: UnlockPace.standard.rule)
    #expect(s.kind == .normal)
    #expect(s.plainText == "7 of 36 unlocked, 2 mastered. Listen to P a few more times and T unlocks.")
    #expect(s.runs.first == HomeSummary.Run(text: "7 of 36", isBold: true))
}

@Test func slippingSentence() {
    var p = solidKM()
    for _ in 0..<5 { _ = p.unlockNext() }
    for _ in 0..<20 { p.log("K", .keying, correct: false, rule: UnlockPace.strict.rule); p.log("M", .keying, correct: false, rule: UnlockPace.strict.rule) }
    let s = HomeSummary(progress: p, rule: UnlockPace.standard.rule)
    #expect(s.kind == .slipping)
    #expect(s.plainText == "7 of 36 unlocked, 0 mastered. K and M have gone dim.")
    for _ in 0..<20 { p.log("M", .keying, correct: true, rule: UnlockPace.strict.rule) }
    #expect(HomeSummary(progress: p, rule: UnlockPace.standard.rule).plainText.hasSuffix("K has gone dim."))
}

@Test func slippingListsThreeWithCommas() {
    var p = solidKM()
    for _ in 0..<5 { _ = p.unlockNext() }           // K M R S U A P
    for _ in 0..<20 {
        for c: Character in ["K", "M", "R"] {
            p.log(c, .keying, correct: false, rule: UnlockPace.strict.rule)
            p.log(c, .listening, correct: false, rule: UnlockPace.strict.rule)
        }
    }
    #expect(HomeSummary(progress: p, rule: UnlockPace.standard.rule).plainText.hasSuffix("K, M and R have gone dim."))
}

@Test func completeSentence() {                      // Review Focus 3
    var p = solidKM()
    for _ in 0..<34 { _ = p.unlockNext() }
    let s = HomeSummary(progress: p, rule: UnlockPace.standard.rule)
    #expect(s.kind == .complete)
    #expect(s.plainText == "All 36 unlocked, 2 mastered.")
}

@Test func firstRunOnlyWhileNothingIsLogged() {
    var p = LearnerProgress.initial
    p.log("K", .keying, correct: false, rule: UnlockPace.strict.rule)
    let s = HomeSummary(progress: p, rule: UnlockPace.standard.rule)
    #expect(s.kind == .normal)
    #expect(s.plainText == "2 of 36 unlocked, 0 mastered. Listen to M a few more times and R unlocks.")
}

@Test func tails() {
    #expect(HomeSummary.tail(.keyMore("M"), next: "R") == "Key M a few more times and R unlocks.")
    #expect(HomeSummary.tail(.steady(["K", "M"]), next: "R") == "Steady K and M and R unlocks.")
    #expect(HomeSummary.tail(.steady([]), next: "R") == "A few more clean answers and R unlocks.")
    #expect(HomeSummary.tail(.almost, next: "R") == "R is almost here.")
}

@Test func pendingUnlockSentenceSaysAlmostUnderAStricterPace() {
    let s = HomeSummary(progress: pendingUnderRelaxed(), rule: UnlockPace.strict.rule)
    #expect(s.plainText.hasSuffix("R is almost here."))
}
