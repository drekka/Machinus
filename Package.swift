// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Machinus",
    platforms: [
        .macOS(.v12),
        .iOS(.v16),
        .tvOS(.v16),
    ],
    products: [
        .library(name: "Machinus", targets: ["Machinus"]),
    ],
    dependencies: [
        .package(url: "https://github.com/quick/nimble", .upToNextMajor(from: "11.0.0")),
    ],
    targets: [
        .target(
            name: "Machinus",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "MachinusTests",
            dependencies: [
                "Machinus",
                .product(name: "Nimble", package: "nimble"),
            ],
            path: "Tests"
        ),
    ]
)
