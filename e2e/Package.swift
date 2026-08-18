// swift-tools-version:5.10
// Separate from the root OpenFeature package because CucumberSwift has no watchOS support and
// would otherwise land in every consumer's dependency graph. Run with `../scripts/e2e`.

import PackageDescription

let package = Package(
    name: "OpenFeatureE2E",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
    ],
    dependencies: [
        // `name:` pins the identity to "OpenFeature"; without it it comes from the checkout
        // directory name.
        .package(name: "OpenFeature", path: ".."),
        .package(url: "https://github.com/cucumberswift/CucumberSwift.git", from: "5.0.10"),
    ],
    targets: [
        .testTarget(
            name: "OpenFeatureE2ETests",
            dependencies: [
                .product(name: "OpenFeature", package: "OpenFeature"),
                "CucumberSwift",
            ],
            resources: [
                // .copy, not .process: .process flattens directories, and CucumberSwift resolves
                // features via `bundle.url(forResource: "Features", withExtension: nil)`. The
                // feature files are gitignored; a committed .gitkeep keeps this path resolvable.
                .copy("Features"),
            ]
        ),
    ]
)
