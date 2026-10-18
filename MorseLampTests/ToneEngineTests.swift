import AVFoundation
import Synchronization
import Testing
import MorseCore
@testable import MorseLamp

@MainActor
struct ToneEngineTests {
    private func samples(_ buffer: AVAudioPCMBuffer) -> [Float] {
        Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }

    @Test func keyDownProducesToneWithinAttackRamp() async throws {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)
        try e.enableOfflineRendering(sampleRate: 48_000)
        e.keyDown()
        let buf = try e.renderOffline(frames: 2_400)  // 50 ms
        let s = samples(buf)
        #expect(s.count == 2_400)
        // 5 ms linear attack: every sample sits under the ramp envelope.
        #expect(s[0..<240].enumerated().allSatisfy { i, v in abs(v) <= 0.5 * Float(i + 1) / 240 + 0.001 })
        #expect(s[0..<48].allSatisfy { abs($0) < 0.11 })  // first 1 ms still ramping
        #expect(s[480..<960].contains { abs($0) > 0.3 })  // audible by 10 ms
    }

    /// The render callback runs on the real audio thread; it must not trap under MainActor default isolation.
    @Test func liveEngineRendersOffTheMainThread() async throws {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)
        await e.start()
        e.keyDown()
        try await Task.sleep(for: .milliseconds(300))
        e.keyUp()
        #expect(e.liveRenderCount > 0)
        e.stop()
    }

    @Test func stopDuringPlayReturns() async throws {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)
        try e.enableOfflineRendering(sampleRate: 48_000)  // nobody renders, so only stop() can end play()
        let done = DoneFlag()
        Task { @MainActor in
            await e.play(PlaybackSchedule(code: Morse.code(for: "0")!, wpm: 5))
            done.set()
        }
        try await Task.sleep(for: .milliseconds(50))
        e.stop()
        #expect(await finishes(done, within: .seconds(2)))
    }

    @Test func playWithoutRunningEngineReturns() async throws {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)  // never started
        let done = DoneFlag()
        Task { @MainActor in
            await e.play(PlaybackSchedule(code: Morse.code(for: "E")!, wpm: 15))
            done.set()
        }
        #expect(await finishes(done, within: .seconds(2)))
    }

    @Test func reinstalledScheduleReplaysFromTheStart() throws {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)
        try e.enableOfflineRendering(sampleRate: 48_000)
        let k = PlaybackSchedule(code: Morse.code(for: "K")!, wpm: 15)
        e.schedule(k)
        _ = try e.renderOffline(frames: 48_000)  // finished
        #expect(e.currentElementIndex == nil)
        e.schedule(k)
        _ = try e.renderOffline(frames: 4_800)  // t = 0.10 s of the second run
        #expect(e.currentElementIndex == 0)
    }

    private func finishes(_ done: DoneFlag, within limit: Duration) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + limit
        while clock.now < deadline {
            if done.isSet { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return done.isSet
    }

    @Test func stopClosesGate() throws {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)
        try e.enableOfflineRendering(sampleRate: 48_000)
        e.keyDown()
        e.stop()
        let buf = try e.renderOffline(frames: 4_800)
        let tail = samples(buf).suffix(2_400)
        #expect(tail.allSatisfy { abs($0) < 0.001 })
    }

    @Test func scheduledPlaybackSetsElementIndexFromRenderPosition() throws {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)
        try e.enableOfflineRendering(sampleRate: 48_000)
        e.schedule(PlaybackSchedule(code: Morse.code(for: "K")!, wpm: 15))  // dash 0–0.24, dot 0.32–0.40, dash 0.48–0.72
        _ = try e.renderOffline(frames: 4_800)  // t = 0.10 s
        #expect(e.currentElementIndex == 0)
        _ = try e.renderOffline(frames: 8_640)  // t = 0.28 s, gap
        #expect(e.currentElementIndex == nil)
        _ = try e.renderOffline(frames: 2_880)  // t = 0.34 s, dot
        #expect(e.currentElementIndex == 1)
        _ = try e.renderOffline(frames: 24_000)  // t = 0.84 s, finished
        #expect(e.currentElementIndex == nil)
    }

    @Test func silentTonePlaysForScheduleDuration() async throws {
        let lamp = LampState()
        let t = SilentTone(lamp: lamp)
        let clock = ContinuousClock()
        let start = clock.now
        await t.play(PlaybackSchedule(code: Morse.code(for: "E")!, wpm: 15))  // 0.08 s
        #expect(clock.now - start >= .milliseconds(80))
        #expect(!lamp.isLit)
        #expect(lamp.litElementIndex == nil)
    }

    @Test func sessionMixesWithOthers() async {
        let e = ToneEngine(lamp: LampState(), pitchHz: 600)
        await e.start()
        let session = AVAudioSession.sharedInstance()
        #expect(session.category == .playback)
        #expect(session.categoryOptions.contains(.mixWithOthers))
        e.stop()
    }
}

private final class DoneFlag: Sendable {
    private let flag = Atomic<Bool>(false)
    var isSet: Bool { flag.load(ordering: .acquiring) }
    func set() { flag.store(true, ordering: .releasing) }
}
