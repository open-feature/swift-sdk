// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenFeature",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "OpenFeature",
            targets: ["OpenFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OpenFeature",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "OpenFeatureTests",
            dependencies: [
                "OpenFeature",
                .product(name: "Logging", package: "swift-log"),
            ]),
    ]
)
