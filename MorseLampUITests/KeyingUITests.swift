import XCTest

final class KeyingUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", "fresh", "--rng-seed", "1", "--silent-audio"]
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

    private static let codes: [String: String] = ["K": "— · —", "M": "— —"]
}
