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