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

/// The same 80 correct logs as `solidKM()`, judged by a rule that never holds, so the pending
/// unlock stays unflagged: for outlooks of a set that has slipped below the rule since.
func unflaggedSolidKM() -> LearnerProgress {
    let never = UnlockRule(newestFloor: .max, setWindow: 50, setFloor: 20, accuracy: 0.90)
    var p = LearnerProgress.initial
    for _ in 0..<20 {
        for skill in Skill.allCases {
            p.log("K", skill, correct: true, rule: never)
            p.log("M", skill, correct: true, rule: never)
        }
    }
    return p
}
