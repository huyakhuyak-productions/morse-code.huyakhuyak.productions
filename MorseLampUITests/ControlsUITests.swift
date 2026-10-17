import XCTest

final class ControlsUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["--screen", "controls", "--silent-audio", "--reset-state"]
        app.launch()
    }

    @MainActor
    func testSwitchExposesToggleValue() {
        launch()
        // The toggle trait makes the system expose the control as a switch.
        let sw = app.switches["Strict timing"]
        XCTAssertTrue(sw.waitForExistence(timeout: 5))
        XCTAssertEqual(sw.value as? String, "off")
        sw.tap()
        XCTAssertEqual(sw.value as? String, "on")
    }

    @MainActor
    func testSegmentedSelectsOnTap() {
        launch()
        XCTAssertTrue(app.buttons["Keyboard"].waitForExistence(timeout: 5))
        app.buttons["Keyboard"].tap()
        XCTAssertTrue(app.buttons["Keyboard"].isSelected)
        XCTAssertFalse(app.buttons["Automatic"].isSelected)
    }

    @MainActor
    func testSliderAdjusts() {
        launch()
        let slider = app.otherElements["Character speed"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertEqual(slider.value as? String, "15 wpm")
        let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        let end = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertNotEqual(slider.value as? String, "15 wpm")
    }

    @MainActor
    func testConfirmSheetCancelAndConfirm() {
        launch()
        let reset = app.buttons["Reset progress"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        let title = app.staticTexts["Reset all progress?"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(of: title))
        reset.tap()
        XCTAssertTrue(app.buttons["Reset"].waitForExistence(timeout: 2))
        app.buttons["Reset"].tap()
        XCTAssertTrue(app.staticTexts["Confirmed"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testPaddleReportsPresses() {
        launch()
        let paddle = app.otherElements["Key"]
        XCTAssertTrue(paddle.waitForExistence(timeout: 5))
        paddle.tap()
        XCTAssertTrue(app.staticTexts["·"].waitForExistence(timeout: 1))
        paddle.press(forDuration: 0.5)
        XCTAssertTrue(app.staticTexts["· —"].waitForExistence(timeout: 1))
    }

    @MainActor
    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
