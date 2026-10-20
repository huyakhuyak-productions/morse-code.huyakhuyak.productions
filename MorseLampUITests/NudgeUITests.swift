import XCTest

final class NudgeUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    /// `listeningBehind` has M keyed well past the floor and never heard: one more M keying offers
    /// the listening drill, "Listen now" swaps drills in place, and the offer never comes back for M.
    @MainActor
    func testKeyingPlentyOffersListening() throws {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", "listeningBehind", "--first-target", "M", "--silent-audio", "--rng-seed", "1"]
        app.launch()
        app.buttons["Key"].tap()
        let target = app.staticTexts["target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "M")
        let paddle = app.otherElements["Key"]
        paddle.press(forDuration: 0.4)
        paddle.press(forDuration: 0.4)

        XCTAssertTrue(app.staticTexts["Try listening?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["You've keyed plenty. R is waiting on your ear: listen for M."].exists)
        XCTAssertTrue(app.buttons["Keep keying"].exists)
        // The modal sheet surfaces as an alert. The drill behind it is dimmed by the scrim on
        // purpose, so only the sheet's own contrast counts.
        let sheet = app.alerts.firstMatch.frame
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
            if issue.auditType == .contrast, let frame = issue.element?.frame, !sheet.contains(frame) { return true }
            return AccessibilityUITests.isByDesign(issue)
        }
        app.buttons["Listen now"].tap()

        // The listening drill replaced the keying one: one back button, and its round plays out.
        let lamp = app.buttons["lamp"]
        XCTAssertTrue(lamp.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Answer M"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "back").count, 1)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'ready'"), object: lamp)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 5), .completed)

        app.buttons["back"].tap()
        app.buttons["Key"].tap()
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "M")
        paddle.press(forDuration: 0.4)
        paddle.press(forDuration: 0.4)
        // The hold is over once the next prompt replaces M; that is where the sheet would show.
        let nextPrompt = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != 'M'"), object: target)
        XCTAssertEqual(XCTWaiter().wait(for: [nextPrompt], timeout: 3), .completed)
        XCTAssertFalse(app.staticTexts["Try listening?"].exists)
        XCTAssertFalse(app.buttons["Keep keying"].exists)
    }
}
