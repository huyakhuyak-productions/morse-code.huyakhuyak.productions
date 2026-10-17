import Foundation
import Testing
import MorseCore
@testable import MorseLamp

struct StateStoreTests {
    @Test func fileStoreRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        let store = FileStateStore(url: url)
        #expect(try store.load() == nil)
        var s = AppState()
        s.settings.wpm = 22
        s.progress.log("K", .keying, correct: true)
        try store.save(s)
        #expect(try store.load() == s)
    }

    /// A field added in a later build must not make an older file undecodable.
    @Test func decodesStateWithMissingKeys() throws {
        let json = Data(#"{"settings":{"wpm":22},"hasKeyed":true}"#.utf8)
        let state = try JSONDecoder().decode(AppState.self, from: json)
        #expect(state.settings.wpm == 22)
        #expect(state.settings.pitchHz == 600)
        #expect(state.hasKeyed)
        #expect(state.progress == .initial)
        #expect(state.estimator == DitEstimator())
    }

    /// An unreadable file is set aside, never silently overwritten by the next save.
    @Test func unreadableFileIsMovedAside() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "state.json")
        try Data("not json".utf8).write(to: url)
        let store = FileStateStore(url: url)
        #expect(throws: (any Error).self) { try store.load() }
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        let siblings = try FileManager.default.contentsOfDirectory(atPath: dir.path(percentEncoded: false))
        #expect(siblings.contains { $0.hasPrefix("state") && $0.contains("unreadable") })
    }

    @Test func settingsDefaultsMatchSpec() {
        let s = Settings()
        #expect(!s.strictTiming)
        #expect(s.answerMode == .automatic)
        #expect(s.wpm == 15)
        #expect(s.pitchHz == 600)
        #expect(s.haptics)
        #expect(s.theme == .system)
        #expect(!s.codesOnLocked)
    }

    @Test func launchConfigurationParses() {
        let c = LaunchConfiguration(arguments: ["MorseLamp", "--fixture", "tenUnlocked", "--rng-seed", "42", "--silent-audio"])
        #expect(c == LaunchConfiguration(resetState: false, fixture: "tenUnlocked", rngSeed: 42, silentAudio: true))
    }
}
