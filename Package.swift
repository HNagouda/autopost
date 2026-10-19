// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Autopost",
    platforms: [.macOS(.v14)],
    targets: [
        // Layout, rendering and export live apart from the UI so they can be tested without a window.
        .target(name: "AutopostCore"),
        .executableTarget(name: "Autopost", dependencies: ["AutopostCore"]),
        .testTarget(name: "AutopostCoreTests", dependencies: ["AutopostCore"]),
    ],
    // Swift 5 mode: AppKit and ImageIO types are not Sendable yet, and strict checking adds noise without catching real bugs here.
    swiftLanguageModes: [.v5]
)
