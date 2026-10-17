import SwiftUI

/// Placeholder until Task 13 builds the keying drill.
struct KeyingView: View {
    let practice: Character?

    @Environment(\.palette) private var palette

    var body: some View {
        CrossfadeText(practice.map { "Practice \($0)" } ?? "Keying")
            .font(LampFont.title(22))
            .foregroundStyle(palette.fg)
            .toolbar(.hidden, for: .navigationBar)
    }
}
