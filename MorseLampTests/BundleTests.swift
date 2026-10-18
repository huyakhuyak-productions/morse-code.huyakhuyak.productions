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
}
