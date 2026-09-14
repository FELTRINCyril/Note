// swift-tools-version: 6.0
import PackageDescription

// SlateUI : design system (tokens couleurs/typo/espacements, composants atomiques, themes).
// Ne depend que de SwiftUI.
let package = Package(
    name: "SlateUI",
    // Langue source du package (CLAUDE.md §5, base FR + EN). Meme motif que SlateEditor/
    // SlateFeatures : sans cette declaration, `Bundle.module` n'existe pas et ce module
    // ne peut pas porter ses propres chaines visibles (chevrons, chrome de bloc, blocs
    // riches, palette de couleurs...).
    defaultLocalization: "fr",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlateUI", targets: ["SlateUI"])
    ],
    targets: [
        .target(
            name: "SlateUI",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(name: "SlateUITests", dependencies: ["SlateUI"])
    ]
)
