import Testing
import UIKit
@testable import MorseLamp

struct SwipeBackTests {
    @Test func popsOnlyWithAScreenUnderneathAndNothingInTheWay() {
        #expect(SwipeBackRule.canPop(depth: 1, transitioning: false, blocked: false) == false)
        #expect(SwipeBackRule.canPop(depth: 2, transitioning: false, blocked: false))
        #expect(SwipeBackRule.canPop(depth: 2, transitioning: true, blocked: false) == false)
        #expect(SwipeBackRule.canPop(depth: 2, transitioning: false, blocked: true) == false)
    }

    @MainActor
    @Test func stayBlockedUntilEverySheetHasGone() {
        let delegate = SwipeBackDelegate()
        let nudge = UUID()
        let confirm = UUID()
        #expect(!delegate.isBlocked)
        delegate.block(nudge)
        delegate.block(confirm)
        delegate.unblock(nudge)
        #expect(delegate.isBlocked)
        delegate.unblock(confirm)
        #expect(!delegate.isBlocked)
    }

    /// Recognisers on the screen's own views wait for the edge swipe, but only where it could pop:
    /// never the stack's sibling recogniser, and never while a sheet blocks the swipe.
    @MainActor
    @Test func otherViewsRecognisersWaitForTheSwipeOnlyWhereItCouldPop() throws {
        let delegate = SwipeBackDelegate()
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.pushViewController(UIViewController(), animated: false)
        navigation.loadViewIfNeeded()
        delegate.install(on: navigation)
        let pop = try #require(navigation.interactivePopGestureRecognizer)
        let sibling = UIPanGestureRecognizer()
        navigation.view.addGestureRecognizer(sibling)
        let screen = UIView()
        let content = UIPanGestureRecognizer()
        screen.addGestureRecognizer(content)
        #expect(delegate.gestureRecognizer(pop, shouldBeRequiredToFailBy: content))
        #expect(delegate.gestureRecognizer(pop, shouldBeRequiredToFailBy: sibling) == false)
        let token = UUID()
        delegate.block(token)
        #expect(delegate.gestureRecognizer(pop, shouldBeRequiredToFailBy: content) == false)
        delegate.unblock(token)
        navigation.popViewController(animated: false)
        #expect(delegate.gestureRecognizer(pop, shouldBeRequiredToFailBy: content) == false)
        withExtendedLifetime(screen) {}
    }

    @MainActor
    @Test func refusesTheGestureBeforeItKnowsTheStack() {
        let delegate = SwipeBackDelegate()
        #expect(delegate.gestureRecognizerShouldBegin(UIGestureRecognizer()) == false)
    }
}
