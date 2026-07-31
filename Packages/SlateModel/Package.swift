// swift-tools-version: 6.0
import PackageDescription

// SlateModel : modeles SwiftData, ModelContainer, requetes, migrations, config CloudKit.
// Ne depend de rien (aucune notion d'UI).
let package = Package(
    name: "SlateModel",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlateModel", targets: ["SlateModel"])
    ],
    targets: [
        .target(name: "SlateModel"),
        .testTarget(name: "SlateModelTests", dependencies: ["SlateModel"])
    ]
)
