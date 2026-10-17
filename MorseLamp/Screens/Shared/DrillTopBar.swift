import SwiftUI

/// Back chevron, the 36-tick row, and the unlocked count. Shared by both drills.
struct DrillTopBar: View {
    let unlocked: Int
    let hasNext: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    init(unlocked: Int, hasNext: Bool) {
        self.unlocked = unlocked
        self.hasNext = hasNext
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .accessibilityIdentifier("back")
            .accessibilityLabel("Back")
            TickRow(unlocked: unlocked, hasNext: hasNext)
            CrossfadeText("\(unlocked)")
                .font(LampFont.body(15, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(palette.fgDim)
                .frame(minWidth: 24, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }
}
