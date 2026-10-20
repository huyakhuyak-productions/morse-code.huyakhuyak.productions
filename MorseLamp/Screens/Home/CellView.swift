import MorseCore
import SwiftUI

nonisolated enum CellState: Equatable {
    case locked
    /// `fraction`: the unlock distance, 0...1.
    case next(fraction: Double)
    case unlocked(Level)
}

/// Pure rules for the home grid: what a cell is and what it says.
nonisolated enum HomeCells {
    static func state(of character: Character, in progress: LearnerProgress, nextFraction: Double) -> CellState {
        if progress.unlocked.contains(character) {
            return .unlocked(progress.level(of: character))
        }
        return progress.next == character ? .next(fraction: nextFraction) : .locked
    }

    /// "K, mastered" / "P, unlocks next" / "P, unlocks next, 60% there" / "Q, locked".
    static func accessibilityLabel(_ character: Character, _ state: CellState) -> String {
        switch state {
        case .locked: "\(character), locked"
        case .next(let fraction):
            if let distance = UnlockOutlook.percentLabel(of: fraction) { "\(character), unlocks next, \(distance)" } else { "\(character), unlocks next" }
        case .unlocked(let level): "\(character), \(name(of: level))"
        }
    }

    /// What sits under a home button: the drill the next unlock is waiting on.
    nonisolated struct Caption: Equatable {
        let skill: Skill
        let text: String
    }

    static func caption(for advice: UnlockOutlook.Advice) -> Caption? {
        switch advice {
        case .listenMore(let c): Caption(skill: .listening, text: "\(c) needs your ear")
        case .keyMore(let c): Caption(skill: .keying, text: "\(c) needs your hand")
        case .complete, .steady, .almost: nil
        }
    }

    /// "Keying: 17 of the last 20. Nearly there."
    static func skillLine(_ skill: Skill, record: SkillRecord) -> String {
        let count = record.recent.count
        let window = count == LearnerProgress.perSkillWindow ? "of the last \(count)" : "of \(count) so far"
        return "\(skillName(skill)): \(record.correctRecent) \(window). \(sentenceName(of: record.level))"
    }

    static func name(of level: Level) -> String {
        switch level {
        case .new: "new"
        case .learning: "learning"
        case .nearly: "nearly there"
        case .mastered: "mastered"
        }
    }

    private static func sentenceName(of level: Level) -> String {
        switch level {
        case .new: "New."
        case .learning: "Learning."
        case .nearly: "Nearly there."
        case .mastered: "Mastered."
        }
    }

    private static func skillName(_ skill: Skill) -> String {
        switch skill {
        case .keying: "Keying"
        case .listening: "Listening"
        }
    }
}

/// One grid cell: 66 pt tall, 14 pt radius, filled by level; locked cells fade to 22 %; the next
/// cell's ring fills clockwise from the top with the unlock distance.
struct CellView: View {
    let character: Character
    let state: CellState
    let showsCode: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(String(character))
                    .font(LampFont.glyph(22))
                    .tracking(-0.05 * 22)
                if showsCode, let code = Morse.code(for: character) {
                    CodeView(code, scale: .cell, color: textColor)
                }
                if differentiateWithoutColor, case .unlocked(let level) = state, level != .new {
                    HStack(spacing: 2) {
                        ForEach(0..<level.rawValue, id: \.self) { _ in
                            Rectangle().fill(textColor).frame(width: 3, height: 3)
                        }
                    }
                }
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay {
                if case .next(let fraction) = state {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.muted2, lineWidth: 1.5)
                    RingFill(fraction: fraction)
                        .strokeBorder(palette.fg, lineWidth: 1.5)
                        .distanceAnimation(fraction)
                }
            }
            .opacity(state == .locked ? 0.22 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressScale())
        .disabled(state == .locked)
        .accessibilityLabel(HomeCells.accessibilityLabel(character, state))
    }

    private var fill: Color {
        if case .unlocked(let level) = state { return palette.cellFill(level: level) }
        return .clear
    }

    private var textColor: Color {
        if case .unlocked(let level) = state, level >= .nearly { return .white }
        return palette.fg
    }
}
