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
