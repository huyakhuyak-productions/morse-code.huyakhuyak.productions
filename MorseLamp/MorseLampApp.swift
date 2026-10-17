import SwiftUI

@main
struct MorseLampApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        LampFont.registerBundledFonts()
        let launch = LaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        _model = State(initialValue: AppModel(store: FileStateStore(url: FileStateStore.defaultURL()), launch: launch))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.lamp)
                .preferredColorScheme(model.state.settings.theme.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.save() }
        }
    }
}

/// Resolves the palette from the effective appearance once, for every screen below.
private struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LitBackground()
            NavigationStack {
                ContentView()
            }
        }
        .environment(\.palette, Palette.resolve(colorScheme))
        .lampDynamicTypeCap()
    }
}
