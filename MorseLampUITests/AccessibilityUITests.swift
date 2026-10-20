import XCTest

final class AccessibilityUITests: XCTestCase {
    nonisolated override func setUp() {
        continueAfterFailure = true
    }

    /// Xcode's accessibility audit on every screen: contrast, Dynamic Type, element detection,
    /// hit regions and element descriptions.
    @MainActor
    func testAccessibilityAuditOnEveryScreen() throws {
        for screen in ["home", "keying", "listening", "settings"] {
            let app = XCUIApplication()
            app.launchArguments = ["--fixture", "tenUnlocked", "--silent-audio", "--screen", screen, "--first-target", "K"]
            app.launch()
            XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 5), screen)
            try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
                Self.isByDesign(issue)
            }
        }
    }

    /// The spec fixes two things the Dynamic Type check flags: every text stops growing at xxLarge
    /// ("partially unsupported"), and glyphs (cells, drill targets) do not scale at all. Body text
    /// that does not scale is still a failure.
    static func isByDesign(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard issue.auditType == .dynamicType else { return false }
        if issue.compactDescription.contains("partially") { return true }
        let label = issue.element?.label ?? ""
        return label.count == 1
    }
}
