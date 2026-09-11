// swift-tools-version: 6.0
import PackageDescription

// SlateEditor : moteur d'edition par blocs (rendu, focus/caret, menu /, formatage, drag & drop, colonnes).
// Depend de SlateModel + SlateUI.
let package = Package(
    name: "SlateEditor",
    // Langue source du package (CLAUDE.md §5, base FR + EN). Sans cette declaration,
    // `Bundle.module` n'existe pas et le module ne peut pas porter ses propres chaines :
    // il faudrait alors les faire toutes remonter en parametres depuis SlateFeatures, ce
    // qui ne passe pas l'echelle pour les phases 6 (menu /), 7 (formatage) et 8 (blocs
    // speciaux), toutes portees par ce module.
    defaultLocalization: "fr",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlateEditor", targets: ["SlateEditor"])
    ],
    dependencies: [
        .package(path: "../SlateModel"),
        .package(path: "../SlateUI"),
        .package(path: "../SlateServices")
    ],
    targets: [
        .target(
            name: "SlateEditor",
            dependencies: [
                .product(name: "SlateModel", package: "SlateModel"),
                .product(name: "SlateUI", package: "SlateUI"),
                .product(name: "SlateServices", package: "SlateServices")
            ],
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "SlateEditorTests",
            dependencies: [
                "SlateEditor",
                .product(name: "SlateModel", package: "SlateModel"),
                .product(name: "SlateUI", package: "SlateUI"),
                .product(name: "SlateServices", package: "SlateServices")
            ]
        )
    ]
)
