import MorseCore
import SwiftUI
import UIKit

/// The key. One finger, timestamps from the touch event, 104 pt tall with a 24 pt radius.
struct PaddleView: View {
    let onDown: (TimeInterval) -> Void
    let onUp: (TimeInterval) -> Void
    var enabled: Bool
    /// Length of the dot VoiceOver's "Dot" and "Dash" actions synthesise.
    var dit: TimeInterval = DitEstimator.initial

    @State private var isDown = false
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(onDown: @escaping (TimeInterval) -> Void, onUp: @escaping (TimeInterval) -> Void, enabled: Bool, dit: TimeInterval = DitEstimator.initial) {
        self.onDown = onDown
        self.onUp = onUp
        self.enabled = enabled
        self.dit = dit
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.key)
                .scaleEffect(isDown && !reduceMotion ? 0.96 : 1)
                .animation(.lamp(0.08), value: isDown)
            PaddleTouchLayer(
                onDown: { t in
                    isDown = true
                    onDown(t)
                },
                onUp: { t in
                    isDown = false
                    onUp(t)
                },
                enabled: enabled,
                dit: dit
            )
        }
        .frame(height: 104)
    }
}

private struct PaddleTouchLayer: UIViewRepresentable {
    let onDown: (TimeInterval) -> Void
    let onUp: (TimeInterval) -> Void
    let enabled: Bool
    let dit: TimeInterval

    func makeUIView(context: Context) -> PaddleUIView {
        PaddleUIView()
    }

    func updateUIView(_ view: PaddleUIView, context: Context) {
        view.onDown = onDown
        view.onUp = onUp
        view.isEnabledForKeying = enabled
        view.dit = dit
    }
}

/// Touch handling without SwiftUI's gesture pipeline. Only the first finger counts.
final class PaddleUIView: UIView {
    var onDown: (TimeInterval) -> Void = { _ in }
    var onUp: (TimeInterval) -> Void = { _ in }
    var isEnabledForKeying = true
    var dit: TimeInterval = DitEstimator.initial

    private var activeTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = "Key"
        accessibilityHint = "Tap for a dot, hold for a dash"
        accessibilityTraits = [.allowsDirectInteraction]
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Dot", target: self, selector: #selector(keyDot)),
            UIAccessibilityCustomAction(name: "Dash", target: self, selector: #selector(keyDash)),
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabledForKeying, activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        onDown(touch.timestamp)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    private func release(_ touches: Set<UITouch>) {
        guard let active = activeTouch, touches.contains(active) else { return }
        activeTouch = nil
        onUp(active.timestamp)
    }

    @objc private func keyDot() -> Bool { synthesise(units: 1) }
    @objc private func keyDash() -> Bool { synthesise(units: 3) }

    /// A press of `units` dots, for VoiceOver's custom actions.
    private func synthesise(units: Double) -> Bool {
        guard isEnabledForKeying, activeTouch == nil else { return false }
        let down = ProcessInfo.processInfo.systemUptime
        let length = dit * units
        onDown(down)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(length))
            onUp(down + length)
        }
        return true
    }
}
