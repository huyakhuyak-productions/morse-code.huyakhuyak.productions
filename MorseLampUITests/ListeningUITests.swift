import XCTest

final class ListeningUITests: XCTestCase {
    private var app: XCUIApplication!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testChoicesLampAndRevealedCode() {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", "fresh", "--rng-seed", "1", "--silent-audio", "--first-target", "K"]
        app.launch()
        app.buttons["Listen"].tap()
        XCTAssertTrue(app.buttons["Answer K"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Answer M"].exists)
        let lamp = app.buttons["lamp"]
        XCTAssertTrue(lamp.waitForExistence(timeout: 3))
        XCTAssertEqual(lamp.label, "Play again")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'ready'"), object: lamp)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 5), .completed)
        app.buttons["Answer K"].tap()
        // The result shows for 1.1 s; waitForExistence polls once a second, so check at once.
        XCTAssertTrue(app.otherElements["code"].exists)
        XCTAssertTrue(app.staticTexts["K  — · —"].exists)
    }
}
