/// Deterministic random numbers (SplitMix64) for tests and seeded UI-test launches.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Which character to drill next, which answers to offer, which distractors to show.
public enum CharacterPicker {
    /// The newest character weighs 8 until it has 20 attempts in the skill; others weigh 4 − level (minimum 1).
    public static func weight(of character: Character, in progress: Progress, skill: Skill) -> Int {
        if character == progress.newest && progress.record(character, skill).total < Progress.setFloor {
            return 8
        }
        return max(1, 4 - progress.level(of: character, in: skill).rawValue)
    }

    /// Weighted random pick from the unlocked set, avoiding `previous` when another candidate exists.
    public static func pick(
        from progress: Progress,
        skill: Skill,
        avoiding previous: Character?,
        using rng: inout some RandomNumberGenerator
    ) -> Character {
        var candidates = progress.unlocked
        if let previous, candidates.count > 1 {
            candidates.removeAll { $0 == previous }
        }
        let weights = candidates.map { weight(of: $0, in: progress, skill: skill) }
        var roll = Int.random(in: 0..<weights.reduce(0, +), using: &rng)
        for (candidate, weight) in zip(candidates, weights) {
            roll -= weight
            if roll < 0 { return candidate }
        }
        return candidates[candidates.count - 1]
    }

    /// `min(4, unlocked)` answer buttons that always include the answer, shuffled.
    public static func choices(
        answer: Character,
        progress: Progress,
        using rng: inout some RandomNumberGenerator
    ) -> [Character] {
        let count = min(4, progress.unlocked.count)
        let others = progress.unlocked.filter { $0 != answer }.shuffled(using: &rng)
        return ([answer] + others.prefix(count - 1)).shuffled(using: &rng)
    }

    /// Two wrong options for the reveal guess: locked characters first (the learner cannot already
    /// know them), then the lowest-level unlocked characters when fewer than two remain locked.
    public static func distractors(
        for newCharacter: Character,
        progress: Progress,
        using rng: inout some RandomNumberGenerator
    ) -> [Character] {
        var pool = progress.locked.filter { $0 != newCharacter }.shuffled(using: &rng)
        if pool.count < 2 {
            let fill = progress.unlocked
                .filter { $0 != newCharacter && !pool.contains($0) }
                .shuffled(using: &rng)
                .sorted { progress.level(of: $0) < progress.level(of: $1) }
            pool += fill
        }
        return Array(pool.prefix(2))
    }
}
