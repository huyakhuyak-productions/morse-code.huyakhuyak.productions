/// The one sentence at the top of the home screen.
public struct HomeSummary: Sendable, Equatable {
    public struct Run: Sendable, Equatable {
        public let text: String
        public let isBold: Bool

        public init(text: String, isBold: Bool) {
            self.text = text
            self.isBold = isBold
        }
    }

    public enum Kind: Sendable {
        case firstRun
        case normal
        case slipping
        case complete
    }

    public let kind: Kind
    public let runs: [Run]

    public var plainText: String { runs.map(\.text).joined() }

    public init(progress: LearnerProgress, rule: UnlockRule) {
        let total = Morse.kochOrder.count
        let mastered = "\(progress.masteredCount) mastered."
        if progress.isComplete {
            kind = .complete
            runs = [Run(text: "All \(total)", isBold: true), Run(text: " unlocked, \(mastered)", isBold: false)]
        } else if !progress.hasLoggedAttempts {
            let unlocked = progress.unlocked
            let first = String(unlocked[0]), second = String(unlocked[1])
            let next = progress.next.map(String.init) ?? ""
            kind = .firstRun
            runs = [
                Run(text: "Start with ", isBold: false), Run(text: first, isBold: true),
                Run(text: " and ", isBold: false), Run(text: second, isBold: true),
                Run(text: ". Key and listen to them until they stick, and \(next) unlocks.", isBold: false),
            ]
        } else {
            let head = Run(text: "\(progress.unlockedCount) of \(total)", isBold: true)
            let slipping = progress.slipping
            if slipping.isEmpty {
                kind = .normal
                let tail = progress.next.map { Self.tail(UnlockOutlook(progress: progress, rule: rule).advice, next: $0) } ?? ""
                runs = [head, Run(text: " unlocked, \(mastered) \(tail)", isBold: false)]
            } else {
                kind = .slipping
                let verb = slipping.count == 1 ? "has" : "have"
                runs = [head, Run(text: " unlocked, \(mastered) \(Self.list(slipping)) \(verb) gone dim.", isBold: false)]
            }
        }
    }

    /// The advice as the end of a sentence about `next`: "Listen to M a few more times and R unlocks."
    public static func tail(_ advice: UnlockOutlook.Advice, next: Character) -> String {
        switch advice {
        case .complete: "Every character is unlocked."
        case .listenMore(let c): "Listen to \(c) a few more times and \(next) unlocks."
        case .keyMore(let c): "Key \(c) a few more times and \(next) unlocks."
        case .steady(let characters) where characters.isEmpty: "A few more clean answers and \(next) unlocks."
        case .steady(let characters): "Steady \(list(characters)) and \(next) unlocks."
        case .almost: "\(next) is almost here."
        }
    }

    /// "R", "R and U", "R, U and A".
    static func list(_ characters: [Character]) -> String {
        let names = characters.map(String.init)
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
}
