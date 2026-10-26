## Getting Started

To get started, open the project in Xcode and build by Product -> Build.

OpenFeature is not keen on vendor-specific stuff in this library, but if there are changes that need to happen in the spec to enable vendor-specific stuff in user code or other extension points, check out [the spec](https://github.com/open-feature/spec).

### Linting code

Code is automatically linted during build in Xcode, if you need to manually lint:
```shell
brew install swiftlint
swiftlint
```

### Formatting code

You can automatically format your code using:
```shell
./scripts/swift-format
```

### Running tests from cmd-line

```shell
swift test
```

On older toolchains, `swift test` includes the adapter tests. With Swift 6.2+, enable the trait to run them:

```shell
swift test --traits SwiftLog
```

SwiftPM selects `Package.swift` on Swift 5.5–6.1 and `Package@swift-6.2.swift` on Swift 6.2+. Keep the core product, platform requirements, resources, and language mode consistent between the manifests.

### Checking core dependency isolation

With Swift 6.2+, run `python3 scripts/check-core-dependencies.py` to verify a fresh core-only consumer resolves no external packages. Older toolchains continue resolving SwiftLog.
