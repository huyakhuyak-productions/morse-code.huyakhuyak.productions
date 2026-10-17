import Testing
@testable import MorseCore

@Test func seededGeneratorIsDeterministic() {
    var a = SeededGenerator(seed: 7)
    var b = SeededGenerator(seed: 7)
    #expect(a.next() == b.next())
    #expect(a.next() == b.next())
    var c = SeededGenerator(seed: 8)
    #expect(a.next() != c.next())
}

@Test func weightsFollowSpec() {
    var p = Progress.initial
    #expect(CharacterPicker.weight(of: "M", in: p, skill: .keying) == 8)     // newest, < 20 attempts
    #expect(CharacterPicker.weight(of: "K", in: p, skill: .keying) == 4)     // level new → 4 − 0
    for _ in 0..<20 { p.log("M", .keying, correct: true); p.log("K", .keying, correct: true) }
    #expect(CharacterPicker.weight(of: "M", in: p, skill: .keying) == 1)     // mastered → 4 − 3
    #expect(CharacterPicker.weight(of: "K", in: p, skill: .keying) == 1)
    #expect(CharacterPicker.weight(of: "M", in: p, skill: .listening) == 8)  // listening still < 20
}

@Test func pickAvoidsImmediateRepeatWhenPossible() {
    var rng = SeededGenerator(seed: 1)
    for _ in 0..<50 {
        #expect(CharacterPicker.pick(from: .initial, skill: .keying, avoiding: "K", using: &rng) == "M")
    }
}

@Test func pickRespectsWeightsRoughly() {
    var rng = SeededGenerator(seed: 2)
    var m = 0
    for _ in 0..<1000 where CharacterPicker.pick(from: .initial, skill: .keying, avoiding: nil, using: &rng) == "M" { m += 1 }
    #expect(m > 550 && m < 780)                      // expected 8/12 ≈ 667
}

@Test func choicesContainAnswerAndCapAtFour() {
    var rng = SeededGenerator(seed: 3)
    #expect(Set(CharacterPicker.choices(answer: "K", progress: .initial, using: &rng)) == ["K", "M"])
    var p = Progress.initial
    for _ in 0..<6 { _ = p.unlockNext() }            // 8 unlocked
    let c = CharacterPicker.choices(answer: "S", progress: p, using: &rng)
    #expect(c.count == 4)
    #expect(c.contains("S"))
    #expect(Set(c).count == 4)
    #expect(c.allSatisfy(p.unlocked.contains))
}

@Test func distractorsComeFromLockedFirst() {
    var rng = SeededGenerator(seed: 4)
    var p = Progress.initial
    let new = p.unlockNext()!                         // R
    let d = CharacterPicker.distractors(for: new, progress: p, using: &rng)
    #expect(d.count == 2)
    #expect(!d.contains(new))
    #expect(Set(d).count == 2)
    #expect(d.allSatisfy(p.locked.contains))
}

@Test func distractorsFillFromLowestLevelUnlockedWhenFewLocked() {
    var rng = SeededGenerator(seed: 5)
    var p = Progress.initial
    for _ in 0..<33 { _ = p.unlockNext() }           // 35 unlocked, 1 locked ("4")
    let new = p.unlockNext()!                         // "4", nothing locked
    let d = CharacterPicker.distractors(for: new, progress: p, using: &rng)
    #expect(d.count == 2)
    #expect(!d.contains(new))
    #expect(Set(d).count == 2)
}

@Test func distractorsPreferLowestLevelWhenFilling() {
    var rng = SeededGenerator(seed: 6)
    var p = solidKM()                                 // K, M mastered
    for _ in 0..<33 { _ = p.unlockNext() }           // 35 unlocked
    let new = p.unlockNext()!                         // "4"
    let d = CharacterPicker.distractors(for: new, progress: p, using: &rng)
    #expect(!d.contains("K") && !d.contains("M"))     // mastered letters are never the fill while "new" ones exist
}
