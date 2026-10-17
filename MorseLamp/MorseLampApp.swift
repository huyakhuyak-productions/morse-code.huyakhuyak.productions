import SwiftUI

@main
struct MorseLampApp: App {
    @State private var lamp = LampState()

    init() {
        LampFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lamp)
        }
    }
}

/// Resolves the palette from the system appearance once, for every screen below.
private struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContentView()
            .environment(\.palette, Palette.resolve(colorScheme))
            .lampDynamicTypeCap()
    }
}
