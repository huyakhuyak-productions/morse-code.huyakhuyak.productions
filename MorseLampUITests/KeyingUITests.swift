import XCTest

final class KeyingUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = [], fixture: String = "fresh") {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", fixture, "--rng-seed", "1", "--silent-audio"] + extra
        app.launch()
    }

    /// Keys a display string such as "— · —" on the paddle: tap for a dot, hold for a dash.
    @MainActor
    private func key(_ display: String) {
        let paddle = app.otherElements["Key"]
        for symbol in display where symbol != " " {
            if symbol == "·" {
                paddle.tap()
            } else {
                paddle.press(forDuration: 0.4)
            }
        }
    }

    @MainActor
    func testMatchThenMissStatuses() {
        launch()
        app.buttons["Key"].tap()
        let targetText = app.staticTexts["target"]
        XCTAssertTrue(targetText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 of 36 unlocked"].exists)   // nothing logged: no distance yet
        let target = targetText.label
        let display = Self.codes[target]!
        key(display)
        XCTAssertTrue(app.staticTexts["\(target)  \(display)"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["back"].frame.size, CGSize(width: 44, height: 44))

        // Wait for the next prompt, then key something wrong.
        let next = NSPredicate(format: "label != %@ OR exists == false", target)
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: next, object: targetText)], timeout: 3)
        XCTAssertTrue(targetText.waitForExistence(timeout: 2))
        let second = targetText.label
        key("· · · · · ·")
        XCTAssertTrue(app.staticTexts["\(second) is \(Self.codes[second]!)"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTickRowReadsTheDistance() {
        launch(["--screen", "keying"], fixture: "listeningBehind")
        XCTAssertTrue(app.staticTexts["2 of 36 unlocked, next 60% there"].waitForExistence(timeout: 5))
    }

    private static let codes: [String: String] = ["K": "— · —", "M": "— —"]
}
