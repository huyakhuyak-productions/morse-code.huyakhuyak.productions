import SwiftUI

/// The 160 pt lamp. Lights full accent with the tone, instantly; shows a play mark when it can replay.
struct LampDisc: View {
    let isLit: Bool
    let showsPlayMark: Bool
    var size: CGFloat = 160
    let action: (() -> Void)?

    @Environment(\.palette) private var palette

    init(isLit: Bool, showsPlayMark: Bool, size: CGFloat = 160, action: (() -> Void)?) {
        self.isLit = isLit
        self.showsPlayMark = showsPlayMark
        self.size = size
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) { disc }
                .buttonStyle(PressScale())
                .accessibilityLabel("Play again")
        } else {
            disc.accessibilityHidden(true)
        }
    }

    private var disc: some View {
        ZStack {
            Circle().fill(isLit ? palette.accent : palette.muted)
            if showsPlayMark && !isLit {
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(palette.fg)
            }
        }
        .frame(width: size, height: size)
        .transaction { $0.animation = nil }
    }
}
