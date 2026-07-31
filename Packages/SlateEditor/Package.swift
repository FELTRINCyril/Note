// swift-tools-version: 6.0
import PackageDescription

// SlateEditor : moteur d'edition par blocs (rendu, focus/caret, menu /, formatage, drag & drop, colonnes).
// Depend de SlateModel + SlateUI.
let package = Package(
    name: "SlateEditor",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlateEditor", targets: ["SlateEditor"])
    ],
    dependencies: [
        .package(path: "../SlateModel"),
        .package(path: "../SlateUI")
    ],
    targets: [
        .target(
            name: "SlateEditor",
            dependencies: [
                .product(name: "SlateModel", package: "SlateModel"),
                .product(name: "SlateUI", package: "SlateUI")
            ]
        ),
        .testTarget(name: "SlateEditorTests", dependencies: ["SlateEditor"])
    ]
)
