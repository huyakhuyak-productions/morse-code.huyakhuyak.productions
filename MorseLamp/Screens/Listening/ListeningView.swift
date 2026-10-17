import SwiftUI

/// Placeholder until Task 14 builds the listening drill.
struct ListeningView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        CrossfadeText("Listening")
            .font(LampFont.title(22))
            .foregroundStyle(palette.fg)
            .toolbar(.hidden, for: .navigationBar)
    }
}
