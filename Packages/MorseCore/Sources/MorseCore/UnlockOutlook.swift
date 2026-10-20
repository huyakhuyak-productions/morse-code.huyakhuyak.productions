import Foundation

/// How far the learner is from the next unlock, and the single most useful next step.
public struct UnlockOutlook: Sendable, Equatable {
    public enum Advice: Sendable, Equatable {
        /// Everything is unlocked.
        case complete
        /// Listening is the blocker; drill this character in it.
        case listenMore(Character)
        /// Keying is the blocker; drill this character in it.
        case keyMore(Character)
        /// Neither skill alone is the blocker. These characters (grid order, at most 3) are below
        /// "nearly" in both skills; empty when only the accuracy window is short.
        case steady([Character])
        /// The next unlock is close, or the rule already holds and the reveal has not run.
        case almost
    }

    /// 0...1; exactly 1 only when the rule holds (or everything is unlocked), otherwise at most 0.99.
    public let fraction: Double
    public let advice: Advice

    /// `fraction` floored to tens, so 0.99 reads 90 and only a held rule reads 100.
    public var percent: Int { Int((fraction * 10).rounded(.down)) * 10 }

    public init(progress: LearnerProgress, rule: UnlockRule) {
        if progress.isComplete {
            fraction = 1
            advice = .complete
            return
        }
        let mean = (Self.seasoning(progress, rule) + Self.readiness(progress) + Self.accuracyVolume(progress, rule)) / 3
        fraction = progress.isSetSolid(rule) ? 1 : min(mean, 0.99)
        advice = Self.advice(progress, rule, fraction: fraction)
    }

    /// True when `advice` names the other skill and the newest character already has at least
    /// `rule.newestFloor + 10` attempts in `skill`: more of this drill will not help.
    public static func suggestsSwitching(from skill: Skill, progress: LearnerProgress, rule: UnlockRule) -> Bool {
        let other: Skill
        switch UnlockOutlook(progress: progress, rule: rule).advice {
        case .listenMore: other = .listening
        case .keyMore: other = .keying
        default: return false
        }
        return other != skill && progress.record(progress.newest, skill).total >= rule.newestFloor + 10
    }

    // MARK: Fraction parts, each in 0...1

    /// The newest character's attempts in each skill against the floor, averaged over the skills.
    private static func seasoning(_ progress: LearnerProgress, _ rule: UnlockRule) -> Double {
        let parts = Skill.allCases.map { min(1, Double(progress.record(progress.newest, $0).total) / Double(rule.newestFloor)) }
        return parts.reduce(0, +) / Double(parts.count)
    }

    /// Share of (unlocked character, skill) pairs that are at least "nearly".
    private static func readiness(_ progress: LearnerProgress) -> Double {
        let pairs = progress.unlocked.flatMap { c in Skill.allCases.map { progress.level(of: c, in: $0) } }
        return Double(pairs.filter { $0 >= .nearly }.count) / Double(pairs.count)
    }

    /// Correct answers in the rule's window against the number the rule needs there.
    private static func accuracyVolume(_ progress: LearnerProgress, _ rule: UnlockRule) -> Double {
        let correct = progress.recentOutcomes(last: rule.setWindow).filter { $0 }.count
        let needed = (rule.accuracy * Double(rule.setWindow)).rounded(.up)
        return min(1, Double(correct) / needed)
    }

    // MARK: Advice

    /// What holds one skill back: the newest character's missing attempts, and the characters
    /// below "nearly" in this skill only.
    private struct Shortfall {
        let skill: Skill
        let missing: Int
        let weak: [Character]

        var isBlocking: Bool { missing > 0 || !weak.isEmpty }
    }

    private static func shortfall(in skill: Skill, other: Skill, _ progress: LearnerProgress, _ rule: UnlockRule) -> Shortfall {
        let missing = max(0, rule.newestFloor - progress.record(progress.newest, skill).total)
        let weak = progress.unlocked.filter { c in
            progress.level(of: c, in: skill) < .nearly && progress.level(of: c, in: other) >= .nearly
        }
        return Shortfall(skill: skill, missing: missing, weak: weak)
    }

    /// True when `a` is further behind than `b`: under the floor beats only weak characters;
    /// both under the floor compare the shortfall (the floor is shared, so attempts compare
    /// the same as fractions of it); both with only weak characters compare how many.
    private static func isFurtherBehind(_ a: Shortfall, than b: Shortfall) -> Bool {
        if (a.missing > 0) != (b.missing > 0) { return a.missing > 0 }
        if a.missing > 0 { return a.missing > b.missing }
        return a.weak.count > b.weak.count
    }

    private static func advice(_ progress: LearnerProgress, _ rule: UnlockRule, fraction: Double) -> Advice {
        let listening = shortfall(in: .listening, other: .keying, progress, rule)
        let keying = shortfall(in: .keying, other: .listening, progress, rule)
        let blockers = [listening, keying].filter(\.isBlocking)
        // Ties go to listening, because keying-only practice is the observed failure.
        if var blocker = blockers.first {
            if blockers.count == 2, isFurtherBehind(keying, than: listening) { blocker = keying }
            let character = blocker.missing > 0 ? progress.newest : weakest(blocker.weak, in: blocker.skill, progress)
            return blocker.skill == .listening ? .listenMore(character) : .keyMore(character)
        }
        let weakInBoth = Set(progress.unlocked.filter { c in Skill.allCases.allSatisfy { progress.level(of: c, in: $0) < .nearly } })
        if !weakInBoth.isEmpty { return .steady(Array(Morse.gridOrder.filter(weakInBoth.contains).prefix(3))) }
        return fraction >= 0.9 ? .almost : .steady([])
    }

    /// The lowest level in `skill`, then the lowest recent accuracy, then grid order.
    private static func weakest(_ characters: [Character], in skill: Skill, _ progress: LearnerProgress) -> Character {
        let ordered = Morse.gridOrder.filter(characters.contains)
        return ordered.min { a, b in
            let ra = progress.record(a, skill), rb = progress.record(b, skill)
            if ra.level != rb.level { return ra.level < rb.level }
            return (ra.accuracy ?? 0) < (rb.accuracy ?? 0)
        } ?? progress.newest
    }
}
