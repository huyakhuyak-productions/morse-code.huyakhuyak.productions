import SwiftUI

/// Back chevron, the 36-tick row, and the unlocked count. Shared by both drills.
struct DrillTopBar: View {
    let unlocked: Int
    let hasNext: Bool
    let nextFraction: Double
    var newestAccent = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    init(unlocked: Int, hasNext: Bool, nextFraction: Double, newestAccent: Bool = false) {
        self.unlocked = unlocked
        self.hasNext = hasNext
        self.nextFraction = nextFraction
        self.newestAccent = newestAccent
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
            TickRow(unlocked: unlocked, hasNext: hasNext, nextFraction: nextFraction, newestAccent: newestAccent)
            CrossfadeText("\(unlocked)")
                .font(LampFont.body(15, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(palette.fgDim)
                .frame(minWidth: 24, alignment: .trailing)
                .accessibilityHidden(true)  // the tick row already says "7 of 36 unlocked"
        }
        .padding(.horizontal, 8)
        // Its own container: without one, a re-render under a dismissing sheet can let the back
        // button's accessibility node adopt the content below it and grow to the full screen.
        .accessibilityElement(children: .contain)
    }
}
