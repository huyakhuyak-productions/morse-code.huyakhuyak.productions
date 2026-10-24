import SwiftUI

/// Full-width, 56 pt, 18 pt radius. Key colours by default, muted for secondary actions, solid red
/// for the confirm sheet's destructive button, and muted with red text for a destructive action
/// that still confirms: it must not read as the screen's main action.
struct PrimaryButton: View {
    enum Role {
        case primary, destructive, mutedDestructive, muted
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
                .foregroundStyle(Self.text(for: role, in: palette))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Self.fill(for: role, in: palette)))
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressScale())
    }

    static func fill(for role: Role, in palette: Palette) -> Color {
        switch role {
        case .primary: palette.key
        case .destructive: palette.bad
        case .mutedDestructive, .muted: palette.muted
        }
    }

    static func text(for role: Role, in palette: Palette) -> Color {
        switch role {
        case .primary: palette.keyText
        case .destructive: .white
        case .mutedDestructive: palette.badText
        case .muted: palette.fg
        }
    }
}
