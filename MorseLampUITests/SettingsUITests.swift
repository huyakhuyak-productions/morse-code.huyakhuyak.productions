import XCTest

final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    @MainActor
    func testControlsConfirmSheetResetAndPersistence() {
        launch(["--fixture", "tenUnlocked", "--silent-audio"])
        app.buttons["Settings"].tap()

        let strict = app.switches["Strict timing"]
        XCTAssertTrue(strict.waitForExistence(timeout: 5))
        XCTAssertEqual(strict.value as? String, "off")
        strict.tap()
        XCTAssertEqual(strict.value as? String, "on")

        app.buttons["Keyboard"].tap()
        XCTAssertTrue(app.buttons["Keyboard"].isSelected)
        XCTAssertTrue(app.staticTexts["The full grid every time."].waitForExistence(timeout: 2))

        let codes = app.switches["Codes on locked letters"]
        app.swipeUp()
        XCTAssertTrue(codes.waitForExistence(timeout: 2))
        XCTAssertEqual(codes.value as? String, "off")

        app.buttons["Strict"].tap()
        XCTAssertTrue(app.buttons["Strict"].isSelected)
        XCTAssertTrue(app.staticTexts["Each letter seasons for 20 rounds in both skills first."].waitForExistence(timeout: 2))

        let reset = app.buttons["Reset progress"]
        XCTAssertTrue(reset.waitForExistence(timeout: 2))
        reset.tap()
        let title = app.staticTexts["Reset all progress?"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["This locks everything except K and M."].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(of: title))
        reset.tap()
        XCTAssertTrue(app.buttons["Reset"].waitForExistence(timeout: 2))
        app.buttons["Reset"].tap()
        XCTAssertTrue(waitForDisappearance(of: title))

        // The back button must still be its 44 pt self after the reset re-rendered the screen.
        let back = app.buttons["back"]
        XCTAssertEqual(back.frame.size, CGSize(width: 44, height: 44))
        back.tap()
        XCTAssertTrue(app.staticTexts["Start with K and M. Key and listen to them until they stick, and R unlocks."].waitForExistence(timeout: 5))

        // Settings survive a relaunch from the saved file; progress stays reset.
        launch(["--silent-audio"])
        app.buttons["Settings"].tap()
        XCTAssertTrue(strict.waitForExistence(timeout: 5))
        XCTAssertEqual(strict.value as? String, "on")
        XCTAssertTrue(app.buttons["Keyboard"].isSelected)
        app.swipeUp()
        XCTAssertTrue(app.buttons["Strict"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Strict"].isSelected)
    }

    @MainActor
    func testRelearnRhythmConfirmSheet() {
        launch(["--fixture", "tenUnlocked", "--silent-audio", "--screen", "settings"])
        let relearn = app.buttons["Relearn my rhythm"]
        XCTAssertTrue(relearn.waitForExistence(timeout: 5))
        relearn.tap()
        let title = app.staticTexts["Relearn my rhythm?"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["The key will measure your dot length again from your next matched characters."].exists)
        app.buttons["Relearn"].tap()
        XCTAssertTrue(waitForDisappearance(of: title))
    }

    @MainActor
    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
