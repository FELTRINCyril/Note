// swift-tools-version: 6.0
import PackageDescription

// SlateFeatures : ecrans complets assembles (sidebar, liste de notes, reglages, bases de donnees, IA).
// Depend de tous les autres modules.
let package = Package(
    name: "SlateFeatures",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlateFeatures", targets: ["SlateFeatures"])
    ],
    dependencies: [
        .package(path: "../SlateModel"),
        .package(path: "../SlateUI"),
        .package(path: "../SlateEditor"),
        .package(path: "../SlateServices")
    ],
    targets: [
        .target(
            name: "SlateFeatures",
            dependencies: [
                .product(name: "SlateModel", package: "SlateModel"),
                .product(name: "SlateUI", package: "SlateUI"),
                .product(name: "SlateEditor", package: "SlateEditor"),
                .product(name: "SlateServices", package: "SlateServices")
            ]
        ),
        .testTarget(name: "SlateFeaturesTests", dependencies: ["SlateFeatures"])
    ]
)
