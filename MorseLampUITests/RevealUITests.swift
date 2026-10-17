import XCTest

final class RevealUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    /// One more correct M keying makes the set solid and unlocks R.
    @MainActor
    func testKeyingTheLastNeededMatchRunsTheRevealIntoGuidedRounds() {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", "aboutToUnlock", "--first-target", "M", "--silent-audio", "--rng-seed", "1"]
        app.launch()
        app.buttons["Key"].tap()
        let target = app.staticTexts["target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "M")
        let paddle = app.otherElements["Key"]
        paddle.press(forDuration: 0.4)
        paddle.press(forDuration: 0.4)

        XCTAssertTrue(app.staticTexts["A new letter. Listen."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Which one was it?"].waitForExistence(timeout: 8))
        let guess = app.buttons["Guess R"]
        XCTAssertTrue(guess.exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Guess '")).count, 3)
        guess.tap()
        XCTAssertTrue(app.staticTexts["You guessed it."].waitForExistence(timeout: 3))
        let keepGoing = app.buttons["Keep going"]
        XCTAssertTrue(keepGoing.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["You guessed it. R joins your set, 3 of 36."].exists)
        keepGoing.tap()

        // Guided rounds: the new character with its code shown as a hint.
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        XCTAssertEqual(target.label, "R")
        XCTAssertTrue(app.otherElements["hint"].waitForExistence(timeout: 2))
    }
}
