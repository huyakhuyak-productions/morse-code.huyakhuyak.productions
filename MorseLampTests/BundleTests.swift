import Testing
import UIKit
@testable import MorseLamp

@MainActor
struct BundleTests {
    /// The icon is a layered `.icon` bundle; actool compiles it into `Assets.car` and also
    /// writes flat fallback PNGs named in `CFBundleIconFiles`. `UIImage(named:)` cannot
    /// return a layered icon (it throws "Need an imageRef"), so the test loads the flat file.
    @Test func appIconIsBundled() throws {
        let icons = try #require(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        let name = try #require(primary["CFBundleIconName"] as? String)
        #expect(name == "AppIcon")
        let files = try #require(primary["CFBundleIconFiles"] as? [String])
        let first = try #require(files.first)
        let url = try #require(Bundle.main.url(forResource: "\(first)@2x", withExtension: "png"))
        let image = try #require(UIImage(contentsOfFile: url.path))
        #expect(image.size.width > 0)
    }

    @Test func launchScreenUsesTheAppBackgroundColour() throws {
        let launch = try #require(Bundle.main.infoDictionary?["UILaunchScreen"] as? [String: Any])
        let colorName = try #require(launch["UIColorName"] as? String)
        #expect(colorName == "LaunchBackground")
        let color = try #require(UIColor(named: colorName))
        var dark: CGFloat = -1, light: CGFloat = -1
        #expect(color.resolvedColor(with: .init(userInterfaceStyle: .dark)).getWhite(&dark, alpha: nil))
        #expect(color.resolvedColor(with: .init(userInterfaceStyle: .light)).getWhite(&light, alpha: nil))
        #expect(abs(dark) < 0.001 && abs(light - 1) < 0.001, "dark=\(dark) light=\(light)")
    }
}
