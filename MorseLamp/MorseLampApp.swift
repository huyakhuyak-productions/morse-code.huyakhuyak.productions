import SwiftUI

enum Route: Hashable {
    case keying(practice: Character?)
    case listening
    case settings
}

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
            if phase == .background {
                model.tone.stop()
                model.save()
            }
        }
    }
}

/// Resolves the palette from the effective appearance once, for every screen below.
private struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var path: [Route] = []
    /// Lives here so it outlives every pushed screen; see `SwipeBack.swift`.
    @State private var swipeBack = SwipeBackDelegate()

    var body: some View {
        ZStack {
            LitBackground()
            NavigationStack(path: $path) {
                Group {
                    switch model.launch.screen {
                    case "controls": ControlsGallery()
                    default: HomeView(path: $path)
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .keying(let practice): KeyingView(practice: practice, path: $path)
                        case .listening: ListeningView(path: $path)
                        case .settings: SettingsView()
                        }
                    }
                    .swipeBackToPop(swipeBack)
                }
            }
            .environment(\.swipeBack, swipeBack)
        }
        .environment(\.palette, Palette.resolve(colorScheme))
        .lampDynamicTypeCap()
        .onAppear(perform: openRequestedScreen)
    }

    private func openRequestedScreen() {
        switch model.launch.screen {
        case "keying": path = [.keying(practice: model.launch.firstTarget)]
        case "listening": path = [.listening]
        case "settings": path = [.settings]
        default: break
        }
    }
}
