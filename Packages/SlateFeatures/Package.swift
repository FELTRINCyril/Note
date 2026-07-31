// swift-tools-version: 6.0
import PackageDescription

// SlateFeatures : ecrans complets assembles (sidebar, liste de notes, reglages, bases de donnees, IA).
// Depend de tous les autres modules.
let package = Package(
    name: "SlateFeatures",
    // Langue source du package (CLAUDE.md §5, base FR + EN). Necessaire pour que le
    // String Catalog du module soit compile : dans un package, `String(localized:)`
    // resout contre `Bundle.module`, pas contre le bundle de l'app - les chaines de
    // App/Localizable.xcstrings ne sont donc PAS visibles ici.
    defaultLocalization: "fr",
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
            ],
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(name: "SlateFeaturesTests", dependencies: ["SlateFeatures"])
    ]
)
