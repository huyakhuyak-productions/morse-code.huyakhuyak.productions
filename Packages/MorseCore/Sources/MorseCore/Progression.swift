import Foundation

/// The two skills tracked separately for every character.
public enum Skill: String, Sendable, Codable, CaseIterable {
    case keying
    case listening
}

/// Progress level of one character, from the accuracy of its recent attempts.
public enum Level: Int, Sendable, Comparable, Codable {
    case new = 0
    case learning
    case nearly
    case mastered

    /// Fewer than 5 attempts is always "new"; then ≥ 0.90 mastered, ≥ 0.70 nearly, ≥ 0.40 learning.
    public init(accuracy: Double?, attempts: Int) {
        guard attempts >= 5, let accuracy else {
            self = .new
            return
        }
        switch accuracy {
        case 0.90...: self = .mastered
        case 0.70...: self = .nearly
        case 0.40...: self = .learning
        default: self = .new
        }
    }

    public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Logged attempts of one character in one skill.
public struct SkillRecord: Sendable, Equatable, Codable {
    /// Last 20 outcomes, oldest first.
    public var recent: [Bool] = []
    /// Every attempt ever logged.
    public var total: Int = 0

    public init(recent: [Bool] = [], total: Int = 0) {
        self.recent = recent
        self.total = total
    }

    public var correctRecent: Int { recent.lazy.filter { $0 }.count }

    public var accuracy: Double? {
        recent.isEmpty ? nil : Double(correctRecent) / Double(recent.count)
    }

    public var level: Level { Level(accuracy: accuracy, attempts: recent.count) }

    mutating func append(_ correct: Bool) {
        recent.append(correct)
        if recent.count > Progress.perSkillWindow { recent.removeFirst(recent.count - Progress.perSkillWindow) }
        total += 1
    }
}

/// Which characters are unlocked and how accurate the learner is in each.
public struct Progress: Sendable, Equatable, Codable {
    public static let perSkillWindow = 20
    public static let setWindow = 50
    public static let setFloor = 20

    /// K and M unlocked, nothing logged.
    public static let initial = Progress()

    public private(set) var unlockedCount = 2
    /// The unlock rule became true on a logged correct answer and the reveal has not run yet.
    public private(set) var pendingUnlock = false
    private var records: [String: SkillRecord] = [:]
    /// Last 50 outcomes across the whole set and both skills, oldest first.
    private var recentAcrossSet: [Bool] = []

    private init() {}

    // MARK: Characters

    public var unlocked: [Character] { Array(Morse.kochOrder.prefix(unlockedCount)) }
    public var locked: [Character] { Array(Morse.kochOrder.dropFirst(unlockedCount)) }
    public var next: Character? { isComplete ? nil : Morse.kochOrder[unlockedCount] }
    public var newest: Character { Morse.kochOrder[unlockedCount - 1] }
    public var isComplete: Bool { unlockedCount == Morse.kochOrder.count }

    // MARK: Records and levels

    public func record(_ character: Character, _ skill: Skill) -> SkillRecord {
        records[Self.key(character, skill)] ?? SkillRecord()
    }

    public func level(of character: Character, in skill: Skill) -> Level {
        record(character, skill).level
    }

    /// The lower of the two skill levels; what the home grid shows.
    public func level(of character: Character) -> Level {
        Skill.allCases.map { level(of: character, in: $0) }.min() ?? .new
    }

    /// True once any attempt in any skill has been logged.
    public var hasLoggedAttempts: Bool {
        records.values.contains { $0.total > 0 }
    }

    public var masteredCount: Int {
        unlocked.lazy.filter { level(of: $0) == .mastered }.count
    }

    /// Unlocked characters that have dropped to "learning" or below, in grid order.
    /// The two newest are exempt, and so is any character with fewer than 5 attempts in a
    /// skill: its level is the "new" default, not a measurement, and it never was bright.
    public var slipping: [Character] {
        let exempt = Set(unlocked.suffix(2))
        let dim = Set(unlocked.filter { c in
            !exempt.contains(c)
                && level(of: c) <= .learning
                && Skill.allCases.allSatisfy { record(c, $0).recent.count >= 5 }
        })
        return Morse.gridOrder.filter(dim.contains)
    }

    // MARK: Unlock rule

    /// 1. every unlocked character at least "nearly" in both skills;
    /// 2. the newest has at least 20 logged attempts in each skill;
    /// 3. accuracy over the last 50 attempts across the set (at least 20 available) is ≥ 0.90.
    public var isSetSolid: Bool {
        let allNearly = unlocked.allSatisfy { c in Skill.allCases.allSatisfy { level(of: c, in: $0) >= .nearly } }
        let newestSeasoned = Skill.allCases.allSatisfy { record(newest, $0).total >= Self.setFloor }
        let enough = recentAcrossSet.count >= Self.setFloor
        let correct = recentAcrossSet.lazy.filter { $0 }.count
        let accurate = enough && Double(correct) / Double(recentAcrossSet.count) >= 0.90
        return allNearly && newestSeasoned && accurate
    }

    /// Logs one attempt. A correct answer that makes the set solid flags the pending unlock.
    public mutating func log(_ character: Character, _ skill: Skill, correct: Bool) {
        var rec = record(character, skill)
        rec.append(correct)
        records[Self.key(character, skill)] = rec
        recentAcrossSet.append(correct)
        if recentAcrossSet.count > Self.setWindow { recentAcrossSet.removeFirst(recentAcrossSet.count - Self.setWindow) }
        if correct && !isComplete && isSetSolid { pendingUnlock = true }
    }

    /// Unlocks the next character and clears the pending flag. Nil when everything is unlocked.
    @discardableResult
    public mutating func unlockNext() -> Character? {
        pendingUnlock = false
        guard let next else { return nil }
        unlockedCount += 1
        return next
    }

    /// Back to K and M with nothing logged.
    public mutating func reset() {
        self = .initial
    }

    private static func key(_ character: Character, _ skill: Skill) -> String {
        "\(character)/\(skill.rawValue)"
    }
}
