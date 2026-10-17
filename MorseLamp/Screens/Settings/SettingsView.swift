import SwiftUI

/// Placeholder until Task 16 builds the settings screen.
struct SettingsView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        CrossfadeText("Settings")
            .font(LampFont.title(22))
            .foregroundStyle(palette.fg)
            .toolbar(.hidden, for: .navigationBar)
    }
}
