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

### Maintaining CocoaPods Integration

The project includes CocoaPods support via the `OpenFeature.podspec` file. When making changes:

1. The version in the podspec is automatically updated from `version.txt` during the release process
2. To validate the podspec locally, run:
   ```shell
   pod spec lint OpenFeature.podspec --allow-warnings
   ```
3. The CocoaPods validation and publishing is handled automatically via GitHub workflows on release

#### Token Management

For information on regenerating the CocoaPods trunk token used in CI/CD, see the "CocoaPods Release Token Management" section in [OWNERS.md](OWNERS.md).
