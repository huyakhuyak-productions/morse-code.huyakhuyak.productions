import AVFoundation
import MorseCore
import Synchronization
import os

/// The sound of the key and of played characters, plus the lamp that follows it.
nonisolated protocol Tone: AnyObject, Sendable {
    /// Configures the audio session and engine and starts observing interruptions and routes.
    @MainActor func start() async
    /// Closes the gate, ends any playback, stops the engine and clears the lamp.
    @MainActor func stop()
    /// Opens the gate. Safe from the touch handler; the lamp lights on the main actor.
    func keyDown()
    func keyUp()
    /// Plays one character and returns when it has finished, was stopped, or the task was cancelled.
    /// The lamp follows each element while it sounds.
    @MainActor func play(_ schedule: PlaybackSchedule) async
    @MainActor func setPitch(_ hz: Double)
}

/// A sine at the configured pitch with 5 ms attack and release, gated by an atomic flag that
/// the key flips and a frame-indexed schedule that playback installs.
nonisolated final class ToneEngine: Tone {
    /// Everything the render callback touches: atomics only, plus a try-lock around the schedule.
    /// The audio thread owns `phase`, `gain`, `playhead` and `renderedGeneration`; the main
    /// thread only ever replaces the schedule and bumps `generation`.
    private final class Renderer: Sendable {
        struct Span: Sendable {
            let start: Int
            let end: Int
            let index: Int
        }

        struct FrameSchedule: Sendable {
            let spans: [Span]
            let total: Int
            let generation: Int
        }

        static let amplitude: Float = 0.5
        static let rampSeconds = 0.005

        let gate = Atomic<Bool>(false)
        let pitchHz = Atomic<Double>(600)
        let sampleRate = Atomic<Double>(48_000)
        let phase = Atomic<Double>(0)
        let gain = Atomic<Double>(0)
        /// Frame position inside the schedule being rendered, or -1 when nothing is playing.
        let playhead = Atomic<Int>(-1)
        /// Generation of the schedule the render thread is currently playing.
        let renderedGeneration = Atomic<Int>(0)
        /// Index of the element sounding right now, or -1.
        let elementIndex = Atomic<Int>(-1)
        /// Bumped by every install; `play` waits until `finishedGeneration` reaches its own.
        let generation = Atomic<Int>(0)
        let finishedGeneration = Atomic<Int>(0)
        let schedule = Mutex<FrameSchedule?>(nil)
        /// Number of render callbacks served, for the live-engine test.
        let renderCount = Atomic<Int>(0)

        /// Installs a schedule and returns its generation.
        func install(spans: [Span], total: Int) -> Int {
            let next = generation.wrappingAdd(1, ordering: .relaxed).newValue
            schedule.withLock { $0 = FrameSchedule(spans: spans, total: total, generation: next) }
            return next
        }

        /// Removes the schedule and marks every installed generation finished.
        func clearSchedule() {
            schedule.withLock { $0 = nil }
            finishedGeneration.store(generation.load(ordering: .relaxed), ordering: .releasing)
            elementIndex.store(-1, ordering: .relaxed)
        }

        func render(frameCount: AVAudioFrameCount, into abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
            renderCount.wrappingAdd(1, ordering: .relaxed)
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            let rate = sampleRate.load(ordering: .relaxed)
            let step = 2 * Double.pi * pitchHz.load(ordering: .relaxed) / rate
            let rampStep = 1 / (Self.rampSeconds * rate)
            let keyed = gate.load(ordering: .acquiring)
            var phase = self.phase.load(ordering: .relaxed)
            var gain = self.gain.load(ordering: .relaxed)
            var head = playhead.load(ordering: .relaxed)
            // A try-lock keeps the audio thread from ever blocking; a block rendered while a
            // schedule is being installed simply keeps the previous state for one buffer.
            let slot = schedule.withLockIfAvailable { $0 }
            var installed: FrameSchedule? = nil
            if let slot {
                installed = slot
                if let slot {
                    if slot.generation != renderedGeneration.load(ordering: .relaxed) {
                        renderedGeneration.store(slot.generation, ordering: .relaxed)
                        head = 0
                    }
                } else {
                    head = -1
                }
            }
            var index = -1

            for frame in 0..<Int(frameCount) {
                var scheduledOn = false
                if head >= 0, let current = installed {
                    if head >= current.total {
                        head = -1
                        finishedGeneration.store(current.generation, ordering: .releasing)
                    } else {
                        for span in current.spans where span.start <= head && head < span.end {
                            scheduledOn = true
                            index = span.index
                            break
                        }
                        head += 1
                    }
                }
                if !scheduledOn { index = -1 }
                let target = keyed || scheduledOn ? 1.0 : 0.0
                if gain < target { gain = min(target, gain + rampStep) } else if gain > target { gain = max(target, gain - rampStep) }
                let sample = Float(sin(phase) * gain) * Self.amplitude
                phase += step
                if phase > 2 * Double.pi { phase -= 2 * Double.pi }
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }

            self.phase.store(phase, ordering: .relaxed)
            self.gain.store(gain, ordering: .relaxed)
            playhead.store(head, ordering: .relaxed)
            elementIndex.store(index, ordering: .releasing)
            return noErr
        }

        /// The render callback. Built here, outside any actor, so it carries no isolation.
        static func renderBlock(for renderer: Renderer) -> AVAudioSourceNodeRenderBlock {
            { @Sendable _, _, frameCount, abl in
                renderer.render(frameCount: frameCount, into: abl)
            }
        }
    }

    enum RenderError: Error {
        case notOffline
        case format
        case status(AVAudioEngineManualRenderingStatus)
    }

    private let lamp: LampState
    private let renderer = Renderer()
    private let logger = Logger(subsystem: LampLog.subsystem, category: "tone")

    @MainActor private let engine = AVAudioEngine()
    @MainActor private var source: AVAudioSourceNode?
    @MainActor private var observers: [any NSObjectProtocol] = []
    @MainActor private var volumeObservation: NSKeyValueObservation?
    @MainActor private var isActive = false

    /// Called on an audio interruption, after playback has been cut.
    @MainActor var onInterruption: (@MainActor () -> Void)?

    @MainActor init(lamp: LampState, pitchHz: Double) {
        self.lamp = lamp
        renderer.pitchHz.store(pitchHz, ordering: .relaxed)
    }

    /// How many times the render callback has run.
    var liveRenderCount: Int { renderer.renderCount.load(ordering: .relaxed) }

    /// The element sounding right now, as seen by the render thread.
    var currentElementIndex: Int? {
        let index = renderer.elementIndex.load(ordering: .acquiring)
        return index >= 0 ? index : nil
    }

    // MARK: Tone

    @MainActor func start() async {
        guard !isActive else { return }
        isActive = true
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            logger.error("Audio session setup failed: \(error, privacy: .public)")
        }
        installObservers()
        updateRoute()
        startEngine()
    }

    @MainActor func stop() {
        renderer.gate.store(false, ordering: .releasing)
        renderer.clearSchedule()
        lamp.isLit = false
        lamp.litElementIndex = nil
        guard isActive else { return }
        isActive = false
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        volumeObservation = nil
        engine.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            logger.error("Audio session deactivation failed: \(error, privacy: .public)")
        }
    }

    func keyDown() {
        renderer.gate.store(true, ordering: .releasing)
        light(true)
    }

    func keyUp() {
        renderer.gate.store(false, ordering: .releasing)
        light(false)
    }

    @MainActor func play(_ schedule: PlaybackSchedule) async {
        guard engine.isRunning else { return }
        let generation = self.schedule(schedule)
        let clock = ContinuousClock()
        // The render thread normally ends playback; the deadline covers an engine that stalls.
        let deadline = clock.now + .seconds(schedule.duration) + .milliseconds(500)
        defer {
            lamp.litElementIndex = nil
            lamp.isLit = renderer.gate.load(ordering: .relaxed)
        }
        while !Task.isCancelled {
            if renderer.finishedGeneration.load(ordering: .acquiring) >= generation { return }
            if clock.now >= deadline {
                renderer.clearSchedule()
                return
            }
            let index = currentElementIndex
            if lamp.litElementIndex != index { lamp.litElementIndex = index }
            let lit = index != nil
            if lamp.isLit != lit { lamp.isLit = lit }
            do {
                try await Task.sleep(for: .milliseconds(4))
            } catch {
                renderer.clearSchedule()
                return
            }
        }
        renderer.clearSchedule()
    }

    @MainActor func setPitch(_ hz: Double) {
        renderer.pitchHz.store(hz, ordering: .relaxed)
    }

    // MARK: Test seams

    /// Puts the engine in offline manual rendering mode at `sampleRate`, mono.
    @MainActor func enableOfflineRendering(sampleRate: Double) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { throw RenderError.format }
        engine.stop()
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_096)
        buildGraph(format: format)
        try engine.start()
    }

    /// Installs a schedule without the lamp polling that `play` adds. Returns its generation.
    @MainActor @discardableResult
    func schedule(_ schedule: PlaybackSchedule) -> Int {
        let rate = renderer.sampleRate.load(ordering: .relaxed)
        let spans = schedule.segments.map {
            Renderer.Span(start: Int(($0.start * rate).rounded()), end: Int(($0.end * rate).rounded()), index: $0.elementIndex)
        }
        return renderer.install(spans: spans, total: Int((schedule.duration * rate).rounded()))
    }

    /// Renders `frames` through the real callback, in offline mode only.
    @MainActor func renderOffline(frames: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        guard engine.isInManualRenderingMode else { throw RenderError.notOffline }
        if !engine.isRunning { try engine.start() }
        let format = engine.manualRenderingFormat
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: engine.manualRenderingMaximumFrameCount)
        else { throw RenderError.format }
        var rendered: AVAudioFrameCount = 0
        while rendered < frames {
            let count = min(frames - rendered, chunk.frameCapacity)
            let status = try engine.renderOffline(count, to: chunk)
            guard status == .success, chunk.frameLength > 0 else { throw RenderError.status(status) }
            for channel in 0..<Int(format.channelCount) {
                let destination = output.floatChannelData![channel] + Int(rendered)
                destination.update(from: chunk.floatChannelData![channel], count: Int(chunk.frameLength))
            }
            rendered += chunk.frameLength
            output.frameLength = rendered
        }
        return output
    }

    // MARK: Engine

    @MainActor private func startEngine() {
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: hardwareRate > 0 ? hardwareRate : 48_000, channels: 1) else { return }
        buildGraph(format: format)
        do {
            try engine.start()
        } catch {
            logger.error("Audio engine failed to start: \(error, privacy: .public)")
        }
    }

    @MainActor private func buildGraph(format: AVAudioFormat) {
        if let source {
            engine.detach(source)
        }
        renderer.sampleRate.store(format.sampleRate, ordering: .relaxed)
        let node = AVAudioSourceNode(format: format, renderBlock: Renderer.renderBlock(for: renderer))
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
        source = node
    }

    /// Interruptions cut playback; route and configuration changes rebuild the graph silently.
    @MainActor private func installObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated { self?.handleInterruption(type) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateRoute() }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildAfterConfigurationChange() }
        })
        volumeObservation = session.observe(\.outputVolume, options: [.initial, .new]) { [weak self] session, _ in
            let muted = session.outputVolume == 0
            Task { @MainActor in self?.lamp.isMuted = muted }
        }
    }

    @MainActor private func handleInterruption(_ type: AVAudioSession.InterruptionType?) {
        switch type {
        case .began:
            renderer.gate.store(false, ordering: .releasing)
            renderer.clearSchedule()
            lamp.isLit = false
            lamp.litElementIndex = nil
            onInterruption?()
        case .ended:
            guard isActive else { return }
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                logger.error("Audio session reactivation failed: \(error, privacy: .public)")
            }
            if !engine.isRunning { startEngine() }
        default:
            break
        }
    }

    @MainActor private func rebuildAfterConfigurationChange() {
        guard isActive, !engine.isInManualRenderingMode else { return }
        engine.stop()
        startEngine()
    }

    @MainActor private func updateRoute() {
        let bluetooth: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP]
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
        lamp.routeIsBluetooth = outputs.contains(where: bluetooth.contains)
    }

    private func light(_ on: Bool) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { lamp.isLit = on }
        } else {
            Task { @MainActor in self.lamp.isLit = on }
        }
    }
}

/// Drives the lamp on the schedule's timeline without an audio engine. Used with `--silent-audio`.
nonisolated final class SilentTone: Tone {
    private let lamp: LampState
    private let keyed = Atomic<Bool>(false)

    init(lamp: LampState) {
        self.lamp = lamp
    }

    @MainActor func start() async {}

    @MainActor func stop() {
        keyed.store(false, ordering: .relaxed)
        lamp.isLit = false
        lamp.litElementIndex = nil
    }

    func keyDown() {
        keyed.store(true, ordering: .relaxed)
        light(true)
    }

    func keyUp() {
        keyed.store(false, ordering: .relaxed)
        light(false)
    }

    @MainActor func play(_ schedule: PlaybackSchedule) async {
        let clock = ContinuousClock()
        let start = clock.now
        defer {
            lamp.litElementIndex = nil
            lamp.isLit = keyed.load(ordering: .relaxed)
        }
        do {
            for segment in schedule.segments {
                try await clock.sleep(until: start + .seconds(segment.start))
                lamp.litElementIndex = segment.elementIndex
                lamp.isLit = true
                try await clock.sleep(until: start + .seconds(segment.end))
                lamp.litElementIndex = nil
                lamp.isLit = false
            }
        } catch {
            return
        }
    }

    @MainActor func setPitch(_ hz: Double) {}

    private func light(_ on: Bool) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { lamp.isLit = on }
        } else {
            Task { @MainActor in self.lamp.isLit = on }
        }
    }
}
