import MorseCore
import SwiftUI

nonisolated enum CellState: Equatable {
    case locked
    case next
    case unlocked(Level)
}

/// Pure rules for the home grid: what a cell is, what it says, and whether its code shows.
nonisolated enum HomeCells {
    static func state(of character: Character, in progress: LearnerProgress) -> CellState {
        if progress.unlocked.contains(character) {
            return .unlocked(progress.level(of: character))
        }
        return progress.next == character ? .next : .locked
    }

    /// "K, mastered" / "P, unlocks next" / "Q, locked".
    static func accessibilityLabel(_ character: Character, _ state: CellState) -> String {
        switch state {
        case .locked: "\(character), locked"
        case .next: "\(character), unlocks next"
        case .unlocked(let level): "\(character), \(name(of: level))"
        }
    }

    /// Unlocked cells always show their code; locked and next cells only when the setting says so.
    static func showsCode(_ state: CellState, codesOnLocked: Bool) -> Bool {
        switch state {
        case .unlocked: true
        case .locked, .next: codesOnLocked
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

/// One grid cell: 66 pt tall, 14 pt radius, filled by level; locked cells fade to 22 %.
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
                if state == .next {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.muted2, lineWidth: 1.5)
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
