import Foundation

/// When each element of one character sounds when played at a given speed.
/// Dot = 1 unit, dash = 3 units, 1 unit of silence between elements.
public struct PlaybackSchedule: Sendable, Equatable {
    public struct Segment: Sendable, Equatable {
        public let elementIndex: Int
        public let start: TimeInterval
        public let end: TimeInterval
    }

    /// Length of one unit in seconds.
    public let unit: TimeInterval
    /// One sounding interval per element, in order.
    public let segments: [Segment]
    /// End of the last segment.
    public let duration: TimeInterval

    /// PARIS timing: a unit is 1200 ms divided by words per minute (floored at 1 wpm).
    public static func unit(wpm: Int) -> TimeInterval {
        1.2 / Double(max(1, wpm))
    }

    public init(code: Code, wpm: Int) {
        let unit = Self.unit(wpm: wpm)
        var segments: [Segment] = []
        var cursor: TimeInterval = 0
        for (index, element) in code.elements.enumerated() {
            let length = unit * (element == .dot ? 1 : 3)
            segments.append(Segment(elementIndex: index, start: cursor, end: cursor + length))
            cursor += length + unit
        }
        self.unit = unit
        self.segments = segments
        self.duration = segments.last?.end ?? 0
    }

    /// The element sounding at `time`, or nil in a gap or after the end.
    public func elementIndex(at time: TimeInterval) -> Int? {
        segments.first { $0.start <= time && time < $0.end }?.elementIndex
    }
}
