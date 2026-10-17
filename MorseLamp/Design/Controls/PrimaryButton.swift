import SwiftUI

/// Full-width, 56 pt, 18 pt radius. Key colours by default, red for destructive, muted for secondary.
struct PrimaryButton: View {
    enum Role {
        case primary, destructive, muted
    }

    let title: String
    let role: Role
    let action: () -> Void

    @Environment(\.palette) private var palette

    init(_ title: String, role: Role = .primary, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            CrossfadeText(title)
                .font(LampFont.title(17))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(background))
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressScale())
    }

    private var background: Color {
        switch role {
        case .primary: palette.key
        case .destructive: palette.bad
        case .muted: palette.muted
        }
    }

    private var foreground: Color {
        switch role {
        case .primary: palette.keyText
        case .destructive: .white
        case .muted: palette.fg
        }
    }
}
