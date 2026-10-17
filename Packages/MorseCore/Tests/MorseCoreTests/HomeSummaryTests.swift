import Testing
@testable import MorseCore

@Test func firstRunSentence() {
    let s = HomeSummary(progress: .initial)
    #expect(s.kind == .firstRun)
    #expect(s.plainText == "Start with K and M. Key them until they stick, and R unlocks.")
    #expect(s.runs.filter(\.isBold).map(\.text) == ["K", "M"])
}

@Test func normalSentence() {
    var p = solidKM()
    for _ in 0..<5 { _ = p.unlockNext() }           // 7 unlocked, K and M mastered
    let s = HomeSummary(progress: p)
    #expect(s.kind == .normal)
    #expect(s.plainText == "7 of 36 unlocked, 2 mastered. T unlocks when your set is solid.")
    #expect(s.runs.first == HomeSummary.Run(text: "7 of 36", isBold: true))
}

@Test func slippingSentence() {
    var p = solidKM()
    for _ in 0..<5 { _ = p.unlockNext() }
    for _ in 0..<20 { p.log("K", .keying, correct: false); p.log("M", .keying, correct: false) }
    let s = HomeSummary(progress: p)
    #expect(s.kind == .slipping)
    #expect(s.plainText == "7 of 36 unlocked, 0 mastered. K and M have gone dim.")
    for _ in 0..<20 { p.log("M", .keying, correct: true) }
    #expect(HomeSummary(progress: p).plainText.hasSuffix("K has gone dim."))
}

@Test func slippingListsThreeWithCommas() {
    var p = solidKM()
    for _ in 0..<5 { _ = p.unlockNext() }           // K M R S U A P
    for _ in 0..<20 {
        for c: Character in ["K", "M", "R"] {
            p.log(c, .keying, correct: false)
            p.log(c, .listening, correct: false)
        }
    }
    #expect(HomeSummary(progress: p).plainText.hasSuffix("K, M and R have gone dim."))
}

@Test func completeSentence() {                      // Review Focus 3
    var p = solidKM()
    for _ in 0..<34 { _ = p.unlockNext() }
    let s = HomeSummary(progress: p)
    #expect(s.kind == .complete)
    #expect(s.plainText == "All 36 unlocked, 2 mastered.")
}

@Test func firstRunOnlyWhileNothingIsLogged() {
    var p = LearnerProgress.initial
    p.log("K", .keying, correct: false)
    let s = HomeSummary(progress: p)
    #expect(s.kind == .normal)
    #expect(s.plainText == "2 of 36 unlocked, 0 mastered. R unlocks when your set is solid.")
}
