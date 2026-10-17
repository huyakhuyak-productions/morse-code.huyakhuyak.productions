import Foundation
import MorseCore

/// Launch arguments for screenshots, audits and tests. All optional; a plain launch changes nothing.
nonisolated struct LaunchConfiguration: Equatable {
    /// Throw away saved state and start fresh.
    var resetState = false
    /// Start from a named `fixtures` entry instead of saved state.
    var fixture: String? = nil
    /// Seed the character picker for repeatable drills.
    var rngSeed: UInt64? = nil
    /// Drive the lamp without the audio engine.
    var silentAudio = false
    /// Open straight on a screen: "keying", "listening", "settings", "gallery".
    var screen: String? = nil
    /// Force the first drill prompt.
    var firstTarget: Character? = nil
}

nonisolated extension LaunchConfiguration {
    /// `["MorseLamp", "--fixture", "tenUnlocked", "--rng-seed", "42", "--silent-audio"]`.
    init(arguments: [String]) {
        self.init()
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--reset-state": resetState = true
            case "--silent-audio": silentAudio = true
            case "--fixture": fixture = iterator.next()
            case "--rng-seed": rngSeed = iterator.next().flatMap { UInt64($0) }
            case "--screen": screen = iterator.next()
            case "--first-target": firstTarget = iterator.next().flatMap { $0.count == 1 ? $0.first : nil }
            default: continue
            }
        }
    }

    static let fixtures: [String: @Sendable () -> AppState] = [
        "fresh": { AppState() },
        "aboutToUnlock": {
            var state = practised(solidKM(skippingLastMKeying: true))
            state.estimator = DitEstimator(dit: 0.12)
            return state
        },
        "tenUnlocked": {
            var state = practised(solidKM(skippingLastMKeying: false))
            for _ in 0..<8 { state.progress.unlockNext() }
            return state
        },
        "complete": {
            var state = practised(solidKM(skippingLastMKeying: false))
            for _ in 0..<34 { state.progress.unlockNext() }
            return state
        },
    ]

    /// K and M with 20 correct attempts in each skill. With the flag, M keying stops at 19, so
    /// one more correct M keying makes the set solid.
    private static func solidKM(skippingLastMKeying: Bool) -> LearnerProgress {
        var progress = LearnerProgress.initial
        for round in 0..<20 {
            for skill in Skill.allCases {
                progress.log("K", skill, correct: true)
                if skippingLastMKeying && skill == .keying && round == 19 { continue }
                progress.log("M", skill, correct: true)
            }
        }
        return progress
    }

    private static func practised(_ progress: LearnerProgress) -> AppState {
        var state = AppState()
        state.progress = progress
        state.hasKeyed = true
        state.hasListened = true
        return state
    }
}
