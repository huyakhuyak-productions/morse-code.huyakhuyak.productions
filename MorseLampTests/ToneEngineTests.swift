import AVFoundation
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
        #expect(s[0..<48].allSatisfy { abs($0) < 0.5 })  // first 1 ms still ramping
        #expect(s[480..<960].contains { abs($0) > 0.3 })  // audible by 10 ms
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
}
