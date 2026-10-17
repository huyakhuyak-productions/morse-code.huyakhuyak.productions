import Foundation

/// One press of the paddle, timestamped from the touch events.
public struct Press: Sendable, Equatable, Codable {
    public let down: TimeInterval
    public let up: TimeInterval

    public init(down: TimeInterval, up: TimeInterval) {
        self.down = down
        self.up = up
    }

    public var duration: TimeInterval { up - down }
}

/// The learned length of the keyer's dot, used to tell dots from dashes.
public struct DitEstimator: Sendable, Equatable, Codable {
    public static let initial: TimeInterval = 0.110
    public static let minimum: TimeInterval = 0.060
    public static let maximum: TimeInterval = 0.250

    public private(set) var dit: TimeInterval

    /// Non-finite values fall back to the initial estimate; everything else is clamped.
    public init(dit: TimeInterval = DitEstimator.initial) {
        self.dit = Self.clamp(dit)
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(dit: try c.decodeIfPresent(TimeInterval.self, forKey: .dit) ?? Self.initial)
    }

    private enum CodingKeys: String, CodingKey { case dit }

    private static func clamp(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return initial }
        return min(maximum, max(minimum, value))
    }

    /// A press shorter than two dots is a dot; anything longer is a dash.
    public func classify(_ press: Press) -> Element {
        press.duration < 2 * dit ? .dot : .dash
    }

    /// Silence after the last release that ends a character.
    public var submitGap: TimeInterval { max(0.6, 4 * dit) }

    /// Fold the presses of a *matched* character into the estimate.
    /// Dots shorter than 1.5 dits contribute their length; dashes contribute a third of theirs.
    /// Only matched characters are learned from, so a drifting estimate cannot ratchet upward.
    public mutating func learn(presses: [Press], elements: [Element]) {
        for (press, element) in zip(presses, elements) {
            let sample: TimeInterval
            switch element {
            case .dot:
                guard press.duration < 1.5 * dit else { continue }
                sample = press.duration
            case .dash:
                sample = press.duration / 3
            }
            dit = Self.clamp(0.7 * dit + 0.3 * sample)
        }
    }
}

/// Strict-timing judgement of a correctly sequenced character.
public enum StrictTiming {
    public static let dotUnits: ClosedRange<Double> = 0.5...1.6
    public static let dashUnits: ClosedRange<Double> = 2.2...4.5

    public enum Problem: Sendable, Equatable { case tooShort, tooLong }

    public struct Fault: Sendable, Equatable {
        /// 1-based position of the element in the sequence.
        public let ordinal: Int
        public let element: Element
        public let problem: Problem

        public init(ordinal: Int, element: Element, problem: Problem) {
            self.ordinal = ordinal
            self.element = element
            self.problem = problem
        }
    }

    /// Slack for floating-point noise so the inclusive bounds really are inclusive.
    private static let epsilon = 1e-9

    /// The first element whose length falls outside tolerance, or nil when all are within it.
    public static func firstFault(presses: [Press], elements: [Element], dit: TimeInterval) -> Fault? {
        for (index, (press, element)) in zip(presses, elements).enumerated() {
            let units = press.duration / dit
            let range = element == .dot ? dotUnits : dashUnits
            if units < range.lowerBound - epsilon {
                return Fault(ordinal: index + 1, element: element, problem: .tooShort)
            }
            if units > range.upperBound + epsilon {
                return Fault(ordinal: index + 1, element: element, problem: .tooLong)
            }
        }
        return nil
    }
}
