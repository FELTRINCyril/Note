// swift-tools-version: 6.0
import PackageDescription

// SlateUI : design system (tokens couleurs/typo/espacements, composants atomiques, themes).
// Ne depend que de SwiftUI.
let package = Package(
    name: "SlateUI",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlateUI", targets: ["SlateUI"])
    ],
    targets: [
        .target(name: "SlateUI"),
        .testTarget(name: "SlateUITests", dependencies: ["SlateUI"])
    ]
)
