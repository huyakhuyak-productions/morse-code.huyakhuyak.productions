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

    /// Recognisers on the screen's own views wait for the edge swipe; the stack's sibling does not.
    @MainActor
    @Test func otherViewsRecognisersWaitForTheSwipe() {
        let delegate = SwipeBackDelegate()
        let container = UIView()
        let pop = UIScreenEdgePanGestureRecognizer()
        container.addGestureRecognizer(pop)
        let sibling = UIPanGestureRecognizer()
        container.addGestureRecognizer(sibling)
        let content = UIPanGestureRecognizer()
        UIView().addGestureRecognizer(content)
        #expect(delegate.gestureRecognizer(pop, shouldBeRequiredToFailBy: content))
        #expect(delegate.gestureRecognizer(pop, shouldBeRequiredToFailBy: sibling) == false)
    }

    @MainActor
    @Test func refusesTheGestureBeforeItKnowsTheStack() {
        let delegate = SwipeBackDelegate()
        #expect(delegate.gestureRecognizerShouldBegin(UIGestureRecognizer()) == false)
    }
}
