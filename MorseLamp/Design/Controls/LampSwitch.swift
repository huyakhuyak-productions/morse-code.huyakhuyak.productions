import SwiftUI

/// A switch drawn in the Lamp style: a button with toggle semantics and an "on"/"off" value.
struct LampSwitch: View {
    let title: String
    let explanation: String?
    @Binding var isOn: Bool

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: String, explanation: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.explanation = explanation
        self._isOn = isOn
    }

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .lamp(0.2)) { isOn.toggle() }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(LampFont.body(17))
                        .foregroundStyle(palette.fg)
                    if let explanation {
                        Text(explanation)
                            .font(LampFont.body(14, relativeTo: .footnote))
                            .foregroundStyle(palette.fgDim)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? palette.accent : palette.muted2)
                    Circle()
                        .fill(.white)
                        .padding(2)
                }
                .frame(width: 51, height: 31)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityHint(explanation ?? "")
        .accessibilityAddTraits(.isToggle)
    }
}
