import XCTest

/// The left-edge swipe pops a pushed screen exactly like the back chevron, and nothing else.
final class SwipeBackUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", "tenUnlocked", "--silent-audio", "--rng-seed", "1"] + extra
        app.launch()
    }

    /// A finger dragged rightward from the left bezel, at a height away from the paddle and sliders.
    @MainActor
    private func swipeBack() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.3))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    private func assertOnHome() {
        XCTAssertTrue(app.buttons["back"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSwipePopsSettings() {
        launch(["--screen", "settings"])
        XCTAssertTrue(app.switches["Strict timing"].waitForExistence(timeout: 5))
        swipeBack()
        assertOnHome()
    }

    @MainActor
    func testSwipePopsKeying() {
        launch(["--screen", "keying", "--first-target", "K"])
        let target = app.staticTexts["target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        swipeBack()
        assertOnHome()
        // The drill left cleanly and starts again.
        app.buttons["Key"].tap()
        XCTAssertTrue(target.waitForExistence(timeout: 5))
    }

    /// A swipe let go early snaps back and leaves the drill as it was.
    @MainActor
    func testSwipeReleasedEarlyStaysOnTheDrill() {
        launch(["--screen", "keying", "--first-target", "K"])
        let target = app.staticTexts["target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.3))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.3))
        // Slow, and still before the finger lifts: a flick would complete the pop.
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertFalse(app.buttons["Settings"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["back"].exists)
        XCTAssertEqual(target.label, "K")
        // The drill still keys: K is dah di dah.
        let paddle = app.otherElements["Key"]
        paddle.press(forDuration: 0.4)
        paddle.tap()
        paddle.press(forDuration: 0.4)
        XCTAssertTrue(app.staticTexts["K  — · —"].waitForExistence(timeout: 3))
    }

    /// The nudge swaps the drill in place; the arriving drill can still be swiped away.
    @MainActor
    func testSwipePopsTheDrillTheNudgeSwitchedTo() {
        app = XCUIApplication()
        // From Home, not `--screen keying`: with a first target that launch opens a practice run.
        app.launchArguments = ["--fixture", "listeningBehind", "--first-target", "M", "--silent-audio", "--rng-seed", "1"]
        app.launch()
        app.buttons["Key"].tap()
        XCTAssertTrue(app.staticTexts["target"].waitForExistence(timeout: 5))
        let paddle = app.otherElements["Key"]
        paddle.press(forDuration: 0.4)
        paddle.press(forDuration: 0.4)
        XCTAssertTrue(app.buttons["Listen now"].waitForExistence(timeout: 3))
        app.buttons["Listen now"].tap()
        XCTAssertTrue(app.buttons["lamp"].waitForExistence(timeout: 3))
        swipeBack()
        assertOnHome()
    }

    @MainActor
    func testSwipePopsListening() {
        launch(["--screen", "listening"])
        XCTAssertTrue(app.buttons["lamp"].waitForExistence(timeout: 5))
        swipeBack()
        assertOnHome()
    }

    @MainActor
    func testSwipeDoesNothingOnHome() {
        launch()
        XCTAssertTrue(app.buttons["Key"].waitForExistence(timeout: 5))
        swipeBack()
        XCTAssertTrue(app.buttons["Key"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
        // The stack still works: a stale gesture delegate at the root would freeze it, and the
        // refused swipe must not leave the gesture dead for the next screen.
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Strict timing"].waitForExistence(timeout: 5))
        swipeBack()
        assertOnHome()
    }

    @MainActor
    func testSwipeIsBlockedUnderConfirmSheet() {
        launch(["--screen", "settings"])
        let reset = app.buttons["Reset progress"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        app.swipeUp()
        reset.tap()
        let title = app.staticTexts["Reset all progress?"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        swipeBack()
        XCTAssertFalse(title.waitForNonExistence(timeout: 1))
        XCTAssertEqual(app.buttons.matching(identifier: "back").count, 1)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 2))
        swipeBack()
        assertOnHome()
    }
}
