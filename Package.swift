// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "SayFlow",
    products: [
        .library(name: "SayFlowCore", targets: ["SayFlowCore"]),
        .executable(name: "SayFlow", targets: ["SayFlow"])
    ],
    targets: [
        .target(
            name: "SayFlowCore"
        ),
        .target(
            name: "SayFlow",
            dependencies: ["SayFlowCore"]
        )
    ],
    swiftLanguageVersions: [5]
)
