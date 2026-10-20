/// What it takes to unlock the next character. A value, so every caller passes the one the
/// learner chose instead of reading a global.
public struct UnlockRule: Sendable, Equatable {
    /// Logged attempts the newest character needs in each skill.
    public let newestFloor: Int
    /// How many of the latest answers across the set the accuracy is judged over.
    public let setWindow: Int
    /// Fewest answers in that window before accuracy counts at all.
    public let setFloor: Int
    /// Share of the window that must be correct.
    public let accuracy: Double

    public init(newestFloor: Int, setWindow: Int, setFloor: Int, accuracy: Double) {
        self.newestFloor = newestFloor
        self.setWindow = setWindow
        self.setFloor = setFloor
        self.accuracy = accuracy
    }
}

/// The learner's choice of how quickly new characters arrive.
public enum UnlockPace: String, Sendable, Codable, CaseIterable {
    case relaxed
    case standard
    case strict

    public var rule: UnlockRule {
        switch self {
        case .relaxed: UnlockRule(newestFloor: 5, setWindow: 20, setFloor: 10, accuracy: 0.85)
        case .standard: UnlockRule(newestFloor: 8, setWindow: 30, setFloor: 12, accuracy: 0.90)
        case .strict: UnlockRule(newestFloor: 20, setWindow: 50, setFloor: 20, accuracy: 0.90)
        }
    }
}
