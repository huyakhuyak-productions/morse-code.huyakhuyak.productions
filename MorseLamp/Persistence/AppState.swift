import MorseCore

nonisolated enum Drill: String, Codable, Sendable {
    case keying, listening
}

/// A freshly unlocked character gets a few guided rounds in the drill it was revealed in.
nonisolated struct GuidedRounds: Codable, Equatable, Sendable {
    var drill: Drill
    var character: Character
    var remaining: Int

    private enum CodingKeys: String, CodingKey { case drill, character, remaining }

    init(drill: Drill, character: Character, remaining: Int) {
        self.drill = drill
        self.character = character
        self.remaining = remaining
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drill = try c.decode(Drill.self, forKey: .drill)
        let text = try c.decode(String.self, forKey: .character)
        guard text.count == 1, let first = text.first else {
            throw DecodingError.dataCorruptedError(forKey: .character, in: c, debugDescription: "Expected one character, got \(text.debugDescription)")
        }
        character = first
        remaining = try c.decode(Int.self, forKey: .remaining)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(drill, forKey: .drill)
        try c.encode(String(character), forKey: .character)
        try c.encode(remaining, forKey: .remaining)
    }
}

/// A "try the other drill" sheet already shown in `drill` while `character` was the newest letter.
nonisolated struct Nudge: Codable, Equatable, Sendable {
    var drill: Drill
    var character: Character

    private enum CodingKeys: String, CodingKey { case drill, character }

    init(drill: Drill, character: Character) {
        self.drill = drill
        self.character = character
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drill = try c.decode(Drill.self, forKey: .drill)
        let text = try c.decode(String.self, forKey: .character)
        guard text.count == 1, let first = text.first else {
            throw DecodingError.dataCorruptedError(forKey: .character, in: c, debugDescription: "Expected one character, got \(text.debugDescription)")
        }
        character = first
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(drill, forKey: .drill)
        try c.encode(String(character), forKey: .character)
    }
}

/// Everything that survives a relaunch, in one document.
nonisolated struct AppState: Codable, Equatable, Sendable {
    var progress = LearnerProgress.initial
    var settings = Settings()
    var estimator = DitEstimator()
    var guided: GuidedRounds? = nil
    /// Nudges already shown, so each (drill, newest letter) pair gets one at most.
    var nudges: [Nudge] = []
    /// The learner has submitted at least one keying attempt; the paddle hint is no longer needed.
    var hasKeyed = false
    var hasListened = false
    var bluetoothNoticeShown = false

    init() {}

    /// Every field is optional on the way in, so a file from an older build still loads.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = try c.decodeIfPresent(LearnerProgress.self, forKey: .progress) ?? progress
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? settings
        estimator = try c.decodeIfPresent(DitEstimator.self, forKey: .estimator) ?? estimator
        // Guided rounds and nudges are disposable: a value this build cannot read is dropped,
        // never allowed to fail the whole file.
        guided = try? c.decodeIfPresent(GuidedRounds.self, forKey: .guided)
        nudges = (try? c.decodeIfPresent([Nudge].self, forKey: .nudges)) ?? []
        hasKeyed = try c.decodeIfPresent(Bool.self, forKey: .hasKeyed) ?? hasKeyed
        hasListened = try c.decodeIfPresent(Bool.self, forKey: .hasListened) ?? hasListened
        bluetoothNoticeShown = try c.decodeIfPresent(Bool.self, forKey: .bluetoothNoticeShown) ?? bluetoothNoticeShown
    }

    private enum CodingKeys: String, CodingKey {
        case progress, settings, estimator, guided, nudges, hasKeyed, hasListened, bluetoothNoticeShown
    }
}
