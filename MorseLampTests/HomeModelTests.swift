import Testing
import MorseCore
@testable import MorseLamp

struct HomeModelTests {
    @Test func cellStates() {
        var p = LearnerProgress.initial
        #expect(HomeCells.state(of: "K", in: p, nextFraction: 0) == .unlocked(.new))
        #expect(HomeCells.state(of: "R", in: p, nextFraction: 0) == .next(fraction: 0))
        #expect(HomeCells.state(of: "R", in: p, nextFraction: 0.666) == .next(fraction: 0.666))
        #expect(HomeCells.state(of: "Q", in: p, nextFraction: 0) == .locked)
        #expect(HomeCells.showsCode(.locked, codesOnLocked: false) == false)
        #expect(HomeCells.showsCode(.next(fraction: 0), codesOnLocked: true))
        #expect(HomeCells.showsCode(.unlocked(.new), codesOnLocked: false))
        #expect(HomeCells.accessibilityLabel("R", .next(fraction: 0)) == "R, unlocks next")
        #expect(HomeCells.accessibilityLabel("R", .next(fraction: 0.666)) == "R, unlocks next, 60% there")
        #expect(HomeCells.accessibilityLabel("K", .unlocked(.nearly)) == "K, nearly there")
        #expect(HomeCells.accessibilityLabel("Q", .locked) == "Q, locked")
        for _ in 0..<34 { _ = p.unlockNext() }
        #expect(Morse.gridOrder.allSatisfy {
            if case .next = HomeCells.state(of: $0, in: p, nextFraction: 1) { false } else { true }
        })
    }

    @Test func sheetLinesCountRecentAttempts() {
        var p = LearnerProgress.initial
        for i in 0..<7 { p.log("K", .keying, correct: i < 4, rule: UnlockPace.standard.rule) }
        #expect(HomeCells.skillLine(.keying, record: p.record("K", .keying)) == "Keying: 4 of 7 so far. Learning.")
        for _ in 0..<20 { p.log("M", .listening, correct: true, rule: UnlockPace.standard.rule) }
        #expect(HomeCells.skillLine(.listening, record: p.record("M", .listening)) == "Listening: 20 of the last 20. Mastered.")
        #expect(HomeCells.skillLine(.listening, record: p.record("K", .listening)) == "Listening: 0 of 0 so far. New.")
    }

    @Test func captions() {
        #expect(HomeCells.caption(for: .listenMore("M")) == .init(skill: .listening, text: "M needs your ear"))
        #expect(HomeCells.caption(for: .keyMore("M")) == .init(skill: .keying, text: "M needs your hand"))
        #expect(HomeCells.caption(for: .steady(["K"])) == nil)
        #expect(HomeCells.caption(for: .almost) == nil)
        #expect(HomeCells.caption(for: .complete) == nil)
    }
}
