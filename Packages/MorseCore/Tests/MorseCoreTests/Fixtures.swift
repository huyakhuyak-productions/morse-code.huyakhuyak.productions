@testable import MorseCore

/// K and M unlocked, 20 correct attempts each in both skills (80 logs). The set is solid.
func solidKM() -> LearnerProgress {
    var p = LearnerProgress.initial
    for _ in 0..<20 {
        for skill in Skill.allCases {
            p.log("K", skill, correct: true, rule: UnlockPace.strict.rule)
            p.log("M", skill, correct: true, rule: UnlockPace.strict.rule)
        }
    }
    return p
}
