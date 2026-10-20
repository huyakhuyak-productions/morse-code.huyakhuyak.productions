import XCTest

final class HomeUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(fixture: String) {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", fixture, "--silent-audio"]
        app.launch()
    }

    @MainActor
    func testFreshHomeShowsFirstRunSentenceAndButtons() {
        launch(fixture: "fresh")
        XCTAssertTrue(app.staticTexts["Start with K and M. Key and listen to them until they stick, and R unlocks."].waitForExistence(timeout: 5))
        let listen = app.buttons["Listen"]
        let key = app.buttons["Key"]
        XCTAssertTrue(listen.exists)
        XCTAssertTrue(key.exists)
        XCTAssertLessThan(listen.frame.midX, key.frame.midX)
        XCTAssertFalse(app.staticTexts["M needs your ear"].exists)
        XCTAssertFalse(app.buttons["Q, locked"].isEnabled)
        app.buttons["K, new"].tap()
        XCTAssertTrue(app.buttons["Practice K"].waitForExistence(timeout: 2))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(app.buttons["R, unlocks next"].waitForExistence(timeout: 2))
        app.buttons["R, unlocks next"].tap()
        XCTAssertTrue(app.staticTexts["Key and listen to K and M until they stick, and R unlocks."].waitForExistence(timeout: 2))
    }

    @MainActor
    func testListeningBehindShowsDistance() {
        launch(fixture: "listeningBehind")
        XCTAssertTrue(app.staticTexts["2 of 36 unlocked, 0 mastered. Listen to M a few more times and R unlocks."].waitForExistence(timeout: 5))
        let caption = app.staticTexts["M needs your ear"]
        XCTAssertTrue(caption.exists)
        XCTAssertLessThan(caption.frame.midX, app.buttons["Key"].frame.midX)
        let next = app.buttons["R, unlocks next, 60% there"]
        XCTAssertTrue(next.exists)
        next.tap()
        XCTAssertTrue(app.staticTexts["Listen to M a few more times and R unlocks."].waitForExistence(timeout: 2))
    }

    /// Off hides every letter's code, in the sheet too; the unlocked sheet keeps its play ring.
    @MainActor
    func testCodesSettingGovernsTheSheet() {
        launch(fixture: "tenUnlocked")
        let cell = app.buttons["R, new"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        XCTAssertTrue(app.buttons["Practice R"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["lamp"].exists)
        XCTAssertFalse(app.otherElements["code"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(app.buttons["Practice R"].waitForNonExistence(timeout: 2))

        app.buttons["Settings"].tap()
        let codes = app.switches["Codes on letters"]
        app.swipeUp()
        XCTAssertTrue(codes.waitForExistence(timeout: 2))
        codes.tap()
        XCTAssertEqual(codes.value as? String, "on")
        app.buttons["back"].tap()

        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        XCTAssertTrue(app.buttons["Practice R"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["code"].exists)
        XCTAssertTrue(app.buttons["lamp"].exists)
    }

    @MainActor
    func testHomeHasNoNextCellWhenComplete() {
        launch(fixture: "complete")
        XCTAssertTrue(app.staticTexts["All 36 unlocked, 2 mastered."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label ENDSWITH 'unlocks next'")).count, 0)
    }
}
