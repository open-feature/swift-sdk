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
            targets: ["OpenFeature"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OpenFeature",
            dependencies: []
        ),
        .testTarget(
            name: "OpenFeatureTests",
            dependencies: ["OpenFeature"]),
    ]
)
