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
    /// Open straight on a screen: "home" (the default), "keying", "listening", "settings", "controls" (the control gallery).
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
        "listeningBehind": {
            var progress = LearnerProgress.initial
            let rule = UnlockPace.standard.rule
            for _ in 0..<18 {
                progress.log("K", .keying, correct: true, rule: rule)
                progress.log("M", .keying, correct: true, rule: rule)
            }
            var state = practised(progress)
            state.hasListened = false
            return state
        },
        "complete": {
            var state = practised(solidKM(skippingLastMKeying: false))
            for _ in 0..<34 { state.progress.unlockNext() }
            return state
        },
    ]

    /// K and M with the Standard newest-letter floor of correct attempts in each skill. With the
    /// flag, M keying stops one short, so one more correct M keying makes the set solid at Standard.
    private static func solidKM(skippingLastMKeying: Bool) -> LearnerProgress {
        var progress = LearnerProgress.initial
        let rule = UnlockPace.standard.rule
        for round in 0..<rule.newestFloor {
            for skill in Skill.allCases {
                progress.log("K", skill, correct: true, rule: rule)
                if skippingLastMKeying && skill == .keying && round == rule.newestFloor - 1 { continue }
                progress.log("M", skill, correct: true, rule: rule)
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
