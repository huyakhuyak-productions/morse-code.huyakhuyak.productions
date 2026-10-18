import XCTest

/// Captures the raw App Store screenshots. Skipped unless `SCREENSHOT_DIR` names a directory;
/// `scripts/screenshots.sh` sets it, runs these on the 6.9" simulator and composes the results.
final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!
    private var directory: URL!

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("SCREENSHOT_DIR not set")
        }
        directory = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = arguments + ["--silent-audio", "--rng-seed", "7"]
        app.launch()
    }

    @MainActor
    private func shoot(_ name: String) throws {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    @MainActor
    func testKeying() throws {
        try launch(["--fixture", "tenUnlocked"])
        app.buttons["Key"].tap()
        XCTAssertTrue(app.staticTexts["target"].waitForExistence(timeout: 5))
        try shoot("keying")
    }

    @MainActor
    func testListening() throws {
        try launch(["--fixture", "tenUnlocked"])
        app.buttons["Listen"].tap()
        XCTAssertTrue(app.buttons["Answer K"].waitForExistence(timeout: 5))
        try shoot("listening")
    }

    @MainActor
    func testHome() throws {
        try launch(["--fixture", "tenUnlocked"])
        XCTAssertTrue(app.buttons["Key"].waitForExistence(timeout: 5))
        try shoot("home")
    }

    @MainActor
    func testReveal() throws {
        try launch(["--fixture", "aboutToUnlock", "--first-target", "M"])
        app.buttons["Key"].tap()
        XCTAssertTrue(app.staticTexts["target"].waitForExistence(timeout: 5))
        let paddle = app.otherElements["Key"]
        paddle.press(forDuration: 0.4)
        paddle.press(forDuration: 0.4)
        XCTAssertTrue(app.staticTexts["Which one was it?"].waitForExistence(timeout: 8))
        // The lead crossfades; the previous text stays in the tree until the transition ends.
        XCTAssertTrue(app.staticTexts["Got it? Once more."].waitForNonExistence(timeout: 3))
        try shoot("reveal")
    }

    @MainActor
    func testSettings() throws {
        try launch(["--fixture", "tenUnlocked"])
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Play sample"].waitForExistence(timeout: 5))
        try shoot("settings")
    }
}
