// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Graker",
    products: [
        .library(name: "GrakerCore", targets: ["GrakerCore"]),
        .executable(name: "Graker", targets: ["Graker"])
    ],
    targets: [
        .target(
            name: "GrakerCore"
        ),
        .target(
            name: "Graker",
            dependencies: ["GrakerCore"]
        )
    ],
    swiftLanguageVersions: [5]
)
