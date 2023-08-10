// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftLinter",
    platforms: [.macOS(.v10_14)],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", revision: "0.50.3")
    ],
    targets: [.target(name: "SwiftLinter", path: "")]
)
