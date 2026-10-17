import SwiftUI

/// Runs `leave` when the scene goes to the background and `resume` only when it comes back from
/// there. `.inactive` → `.active` (Control Center, a banner) is not a return and triggers nothing.
private struct BackgroundReturn: ViewModifier {
    let leave: () -> Void
    let resume: () async -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var inBackground = false

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                inBackground = true
                leave()
            case .active:
                guard inBackground else { return }
                inBackground = false
                Task { await resume() }
            default:
                break
            }
        }
    }
}

extension View {
    func onBackgroundReturn(leave: @escaping () -> Void = {}, resume: @escaping () async -> Void) -> some View {
        modifier(BackgroundReturn(leave: leave, resume: resume))
    }
}
