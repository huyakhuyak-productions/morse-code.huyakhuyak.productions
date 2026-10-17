// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MorseCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "MorseCore", targets: ["MorseCore"]),
    ],
    targets: [
        .target(name: "MorseCore"),
        .testTarget(name: "MorseCoreTests", dependencies: ["MorseCore"]),
    ],
    swiftLanguageModes: [.v6]
)
