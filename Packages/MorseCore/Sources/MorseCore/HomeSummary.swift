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

    public init(progress: LearnerProgress) {
        let total = Morse.kochOrder.count
        let mastered = "\(progress.masteredCount) mastered."
        if !progress.hasLoggedAttempts {
            let unlocked = progress.unlocked
            let first = String(unlocked[0]), second = String(unlocked[1])
            let next = progress.next.map(String.init) ?? ""
            kind = .firstRun
            runs = [
                Run(text: "Start with ", isBold: false), Run(text: first, isBold: true),
                Run(text: " and ", isBold: false), Run(text: second, isBold: true),
                Run(text: ". Key them until they stick, and \(next) unlocks.", isBold: false),
            ]
        } else if progress.isComplete {
            kind = .complete
            runs = [Run(text: "All \(total)", isBold: true), Run(text: " unlocked, \(mastered)", isBold: false)]
        } else {
            let head = Run(text: "\(progress.unlockedCount) of \(total)", isBold: true)
            let slipping = progress.slipping
            if slipping.isEmpty {
                kind = .normal
                let next = progress.next.map(String.init) ?? ""
                runs = [head, Run(text: " unlocked, \(mastered) \(next) unlocks when your set is solid.", isBold: false)]
            } else {
                kind = .slipping
                let verb = slipping.count == 1 ? "has" : "have"
                runs = [head, Run(text: " unlocked, \(mastered) \(Self.list(slipping)) \(verb) gone dim.", isBold: false)]
            }
        }
    }

    /// "R", "R and U", "R, U and A".
    static func list(_ characters: [Character]) -> String {
        let names = characters.map(String.init)
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
}
