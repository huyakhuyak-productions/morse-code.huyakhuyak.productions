import SwiftUI

/// One answer in a drill or the reveal: a muted cell that turns accent when it was the right
/// pick, red when it was the wrong one, and wears an accent ring when it is the answer being shown.
struct AnswerCell: View {
    enum State { case plain, picked, wrongPick, answer }

    let character: Character
    let state: State
    let enabled: Bool
    let height: CGFloat
    /// "Answer K" in the listening drill, "Guess K" in the reveal.
    let label: String
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(String(character))
                .font(LampFont.glyph(height > 60 ? 40 : 22))
                .tracking(-0.05 * (height > 60 ? 40 : 22))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
                .overlay {
                    if state == .answer {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.accent, lineWidth: 2)
                    }
                }
                .opacity(enabled ? 1 : 0.22)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .animation(.lamp(0.2), value: state)
        .accessibilityLabel(label)
    }

    private var fill: Color {
        switch state {
        case .plain, .answer: palette.muted
        case .picked: palette.accent
        case .wrongPick: palette.bad
        }
    }

    private var textColor: Color {
        switch state {
        case .picked, .wrongPick: .white
        case .plain, .answer: palette.fg
        }
    }
}
