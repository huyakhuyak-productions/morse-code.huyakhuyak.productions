import XCTest

/// Drives the app on a physical iPhone for the App Review screen recording.
/// Starts from the Home Screen icon, so the app runs with the owner's real progress and sound.
final class DemoRecordingUITests: XCTestCase {
    nonisolated override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testDemoForAppReview() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Recorded on a physical device only.")
        #endif
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let app = XCUIApplication()

        XCUIDevice.shared.press(.home)
        pause(2)
        // Pressing Home lands on the first page; swipe until the icon is on screen.
        let icons = springboard.icons.matching(identifier: "Morse Lamp")
        var icon: XCUIElement?
        for _ in 0..<8 {
            icon = icons.allElementsBoundByIndex.first { $0.isHittable }
            if icon != nil { break }
            springboard.swipeLeft()
            pause(1)
        }
        guard let icon else {
            XCTFail("Morse Lamp icon not found on any Home Screen page")
            return
        }
        pause(1)
        icon.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        pause(3)

        // Keying: read each target and key its code on the paddle.
        app.buttons["Key"].tap()
        let target = app.staticTexts["target"]
        for _ in 0..<5 {
            guard target.waitForExistence(timeout: 5) else { break }
            let letter = target.label
            guard let code = Self.codes[letter] else { break }
            pause(1)
            key(code, in: app)
            pause(2.5)
        }
        app.buttons["back"].tap()
        pause(2)

        // Listening: let the lamp and tone play, then answer.
        app.buttons["Listen"].tap()
        let lamp = app.buttons["lamp"]
        for _ in 0..<4 {
            guard lamp.waitForExistence(timeout: 5) else { break }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'ready'"), object: lamp)
            _ = XCTWaiter().wait(for: [ready], timeout: 8)
            pause(1)
            let answers = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Answer '"))
            guard answers.count > 0 else { break }
            answers.element(boundBy: 0).tap()
            pause(2.5)
        }
        app.buttons["back"].tap()
        pause(2)

        // Settings.
        app.buttons["settings"].tap()
        pause(3)
        app.swipeUp()
        pause(3)
        app.swipeDown()
        pause(2)
        app.buttons["back"].tap()
        pause(3)
    }

    /// Keys a display string such as "— · —": tap for a dot, hold for a dash.
    @MainActor
    private func key(_ display: String, in app: XCUIApplication) {
        let paddle = app.otherElements["Key"]
        for symbol in display where symbol != " " {
            if symbol == "·" {
                paddle.tap()
            } else {
                paddle.press(forDuration: 0.4)
            }
        }
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private static let codes: [String: String] = [
        "A": "· —", "B": "— · · ·", "C": "— · — ·", "D": "— · ·", "E": "·", "F": "· · — ·",
        "G": "— — ·", "H": "· · · ·", "I": "· ·", "J": "· — — —", "K": "— · —", "L": "· — · ·",
        "M": "— —", "N": "— ·", "O": "— — —", "P": "· — — ·", "Q": "— — · —", "R": "· — ·",
        "S": "· · ·", "T": "—", "U": "· · —", "V": "· · · —", "W": "· — —", "X": "— · · —",
        "Y": "— · — —", "Z": "— — · ·",
        "0": "— — — — —", "1": "· — — — —", "2": "· · — — —", "3": "· · · — —", "4": "· · · · —",
        "5": "· · · · ·", "6": "— · · · ·", "7": "— — · · ·", "8": "— — — · ·", "9": "— — — — ·",
    ]
}
