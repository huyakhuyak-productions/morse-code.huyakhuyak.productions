import CoreHaptics
import os

/// Light transients on press and release, a firmer one on the reveal. Silent where unsupported.
@MainActor
final class Haptics {
    var isEnabled = true

    private var engine: CHHapticEngine?
    private var pressPlayer: (any CHHapticPatternPlayer)?
    private var releasePlayer: (any CHHapticPatternPlayer)?
    private var revealPlayer: (any CHHapticPatternPlayer)?
    private let logger = Logger(subsystem: LampLog.subsystem, category: "haptics")

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.restart() }
            }
            self.engine = engine
            restart()
        } catch {
            logger.error("Haptic engine unavailable: \(error, privacy: .public)")
        }
    }

    func press() { play(pressPlayer) }
    func release() { play(releasePlayer) }
    func reveal() { play(revealPlayer) }

    private func play(_ player: (any CHHapticPatternPlayer)?) {
        guard isEnabled, let player else { return }
        do {
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("Haptic play failed: \(error, privacy: .public)")
        }
    }

    private func restart() {
        guard let engine else { return }
        do {
            try engine.start()
            pressPlayer = try engine.makePlayer(with: Self.transient(intensity: 0.5, sharpness: 0.6))
            releasePlayer = try engine.makePlayer(with: Self.transient(intensity: 0.35, sharpness: 0.4))
            revealPlayer = try engine.makePlayer(with: Self.transient(intensity: 0.9, sharpness: 0.3))
        } catch {
            logger.error("Haptic engine start failed: \(error, privacy: .public)")
        }
    }

    private static func transient(intensity: Float, sharpness: Float) throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        return try CHHapticPattern(events: [event], parameters: [])
    }
}
