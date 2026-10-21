import os
import SwiftUI
import UIKit

/// Hiding the navigation bar switches off the stack's left-edge pop gesture. These pieces hand the
/// stack's own recogniser a delegate again, so a swipe from the left edge pops a pushed screen
/// exactly as the back chevron does, with the system's finger tracking and Reduce Motion handling.
nonisolated enum SwipeBackRule {
    /// Pops only with a screen underneath, no push or pop already animating, and no sheet covering
    /// the back chevron.
    static func canPop(depth: Int, transitioning: Bool, blocked: Bool) -> Bool {
        depth > 1 && !transitioning && !blocked
    }
}

/// One per navigation stack, owned by the root so it outlives every pushed screen (the recogniser
/// holds it weakly). Pushed screens install it; sheets block it while they cover the chevron.
final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    private(set) weak var navigationController: UINavigationController?
    private var blockers: Set<UUID> = []
    private let logger = Logger(subsystem: LampLog.subsystem, category: "navigation")

    var isBlocked: Bool { !blockers.isEmpty }

    func install(on navigation: UINavigationController) {
        navigationController = navigation
        guard let pop = navigation.interactivePopGestureRecognizer, pop.delegate !== self else { return }
        logger.debug("Taking over the pop gesture from \(String(describing: pop.delegate), privacy: .public)")
        pop.delegate = self
    }

    func block(_ token: UUID) { blockers.insert(token) }
    func unblock(_ token: UUID) { blockers.remove(token) }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation = navigationController else { return false }
        return SwipeBackRule.canPop(
            depth: navigation.viewControllers.count,
            transitioning: navigation.transitionCoordinator != nil,
            blocked: isBlocked
        )
    }

    /// Everything on the screens below waits for the edge swipe, as it does under a visible bar.
    /// Without this, SwiftUI's own touch recogniser (left behind by a dismissed Lamp sheet) claims
    /// the touch on its first move and the swipe fails for good. The stack's other recogniser on
    /// the same view is left alone.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        other.view !== gestureRecognizer.view
    }
}

/// A zero-size view that finds the stack's `UINavigationController` through the responder chain
/// once it is in a window. Installing from every pushed screen survives the nudge's in-place
/// route swap, which replaces the top controller.
private struct SwipeBackInstaller: UIViewRepresentable {
    let delegate: SwipeBackDelegate

    func makeUIView(context: Context) -> InstallerView { InstallerView(delegate: delegate) }
    func updateUIView(_ view: InstallerView, context: Context) { view.delegate = delegate }

    final class InstallerView: UIView {
        var delegate: SwipeBackDelegate

        init(delegate: SwipeBackDelegate) {
            self.delegate = delegate
            super.init(frame: .zero)
            isAccessibilityElement = false
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("InstallerView is built in code") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder = next
            while let current = responder {
                if let navigation = current as? UINavigationController {
                    delegate.install(on: navigation)
                    return
                }
                responder = current.next
            }
        }
    }
}

/// Holds a block token for as long as `blocked` is true and the view is on screen.
private struct SwipeBackBlocker: ViewModifier {
    let blocked: Bool

    @State private var token = UUID()
    @Environment(\.swipeBack) private var swipeBack

    func body(content: Content) -> some View {
        content
            .onChange(of: blocked, initial: true) { _, blocked in
                if blocked { swipeBack?.block(token) } else { swipeBack?.unblock(token) }
            }
            .onDisappear { swipeBack?.unblock(token) }
    }
}

extension EnvironmentValues {
    /// The stack's swipe-back gatekeeper; nil outside a navigation stack.
    @Entry var swipeBack: SwipeBackDelegate? = nil
}

extension View {
    /// Lets the left-edge swipe pop this pushed screen.
    func swipeBackToPop(_ delegate: SwipeBackDelegate) -> some View {
        background(SwipeBackInstaller(delegate: delegate).frame(width: 0, height: 0).accessibilityHidden(true))
    }

    /// Stops the left-edge swipe while something covers the back chevron.
    func blocksSwipeBack(_ blocked: Bool) -> some View {
        modifier(SwipeBackBlocker(blocked: blocked))
    }
}
