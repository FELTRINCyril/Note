// swift-tools-version: 6.0
import PackageDescription

// SlateServices : services transverses sans UI (sync CloudKit, verrouillage biometrique,
// import/export, IA, transcription). Depend de SlateModel.
let package = Package(
    name: "SlateServices",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SlateServices", targets: ["SlateServices"])
    ],
    dependencies: [
        .package(path: "../SlateModel")
    ],
    targets: [
        .target(
            name: "SlateServices",
            dependencies: [
                .product(name: "SlateModel", package: "SlateModel")
            ]
        ),
        .testTarget(name: "SlateServicesTests", dependencies: ["SlateServices"])
    ]
)
