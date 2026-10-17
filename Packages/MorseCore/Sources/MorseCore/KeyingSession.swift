import Foundation

/// Collects paddle presses into one character and submits it after a silence.
/// Pure state machine: the caller supplies every timestamp, so it is fully testable.
public struct KeyingSession: Sendable, Equatable {
    public var estimator: DitEstimator
    public private(set) var presses: [Press] = []
    public private(set) var elements: [Element] = []
    public private(set) var isKeyDown = false

    private var downAt: TimeInterval?

    public init(estimator: DitEstimator) {
        self.estimator = estimator
    }

    /// Starts a press. A second finger landing while one is already down is ignored,
    /// so the press keeps the first touch's start time.
    public mutating func keyDown(at t: TimeInterval) {
        guard !isKeyDown else { return }
        downAt = t
        isKeyDown = true
    }

    /// Classifies the finished press and appends it. Nil when no press was in progress.
    public mutating func keyUp(at t: TimeInterval) -> Element? {
        guard let down = downAt else { return nil }
        downAt = nil
        isKeyDown = false
        let press = Press(down: down, up: t)
        let element = estimator.classify(press)
        presses.append(press)
        elements.append(element)
        return element
    }

    /// Submits the pending character once the key is up and the silence since the
    /// last release has reached `estimator.submitGap`. Clears the pending state.
    public mutating func tick(now t: TimeInterval) -> (elements: [Element], presses: [Press])? {
        guard !isKeyDown, let last = presses.last, t - last.up >= estimator.submitGap else { return nil }
        let out = (elements: elements, presses: presses)
        clear()
        return out
    }

    public mutating func clear() {
        presses.removeAll()
        elements.removeAll()
        downAt = nil
        isKeyDown = false
    }
}
