// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Machinus",
    platforms: [
      .macOS(.v10_10), .iOS(.v9), .tvOS(.v9)
    ],
    products: [
        .library(name: "Machinus", targets: ["Machinus"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Machinus",
            dependencies: [
            ],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "MachinusTests",
            dependencies: ["Machinus"],
            exclude: ["objc", "Info.plist"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
