@testable import MorseCore

/// K and M unlocked, 20 correct attempts each in both skills (80 logs). The set is solid.
func solidKM() -> Progress {
    var p = Progress.initial
    for _ in 0..<20 {
        for skill in Skill.allCases {
            p.log("K", skill, correct: true)
            p.log("M", skill, correct: true)
        }
    }
    return p
}
