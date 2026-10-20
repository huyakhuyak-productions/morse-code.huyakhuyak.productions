import MorseCore
import SwiftUI

/// The words of the "try the other drill" sheet, keyed by the drill the learner is in.
nonisolated enum NudgeCopy {
    static func title(from skill: Skill) -> String {
        switch skill {
        case .keying: "Try listening?"
        case .listening: "Try keying?"
        }
    }

    static func message(from skill: Skill, next: Character, character: Character) -> String {
        switch skill {
        case .keying: "You've keyed plenty. \(next) is waiting on your ear: listen for \(character)."
        case .listening: "You've listened plenty. \(next) is waiting on your hand: key \(character)."
        }
    }

    static func switchTitle(from skill: Skill) -> String {
        switch skill {
        case .keying: "Listen now"
        case .listening: "Key now"
        }
    }

    static func stayTitle(from skill: Skill) -> String {
        switch skill {
        case .keying: "Keep keying"
        case .listening: "Keep listening"
        }
    }
}

/// Offered once per new letter when the learner has drilled one skill well past what the unlock
/// needs and the other skill is what holds the next letter back.
struct NudgeSheet: View {
    @Binding var isPresented: Bool
    let skill: Skill
    let next: Character
    let character: Character
    let onSwitch: () -> Void

    @Environment(\.palette) private var palette

    init(isPresented: Binding<Bool>, from skill: Skill, next: Character, character: Character, onSwitch: @escaping () -> Void) {
        self._isPresented = isPresented
        self.skill = skill
        self.next = next
        self.character = character
        self.onSwitch = onSwitch
    }

    var body: some View {
        LampSheet(isPresented: $isPresented, title: NudgeCopy.title(from: skill)) {
            CrossfadeText(NudgeCopy.message(from: skill, next: next, character: character))
                .font(LampFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(palette.fgDim)
            PrimaryButton(NudgeCopy.switchTitle(from: skill)) {
                onSwitch()
                isPresented = false
            }
            PrimaryButton(NudgeCopy.stayTitle(from: skill), role: .muted) {
                isPresented = false
            }
        }
    }
}

extension AppModel {
    /// The letter the nudge asks for in the other drill: the one the unlock advice names.
    var nudgeCharacter: Character {
        switch outlook.advice {
        case .listenMore(let character), .keyMore(let character): character
        default: state.progress.newest
        }
    }
}
