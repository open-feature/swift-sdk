## Getting Started

To get started, open the project in Xcode and build by Product -> Build.

This repository has a submodule holding the OpenFeature specification's shared test suite, so
clone with `git clone --recurse-submodules`, or run `git submodule update --init` in an existing
clone. Only the end-to-end tests need it.

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

### Running the shared Gherkin e2e suite

`e2e/` is a separate Swift package that runs the OpenFeature specification's shared
`evaluation.feature` against `InMemoryProvider` using
[CucumberSwift](https://github.com/cucumberswift/CucumberSwift). It is separate from the root
package because CucumberSwift does not support watchOS and should not reach consumers of the SDK.

```shell
./scripts/e2e
```

That script initialises the [`open-feature/spec`](https://github.com/open-feature/spec) submodule,
copies `spec/specification/assets/gherkin/evaluation.feature` into the test target's gitignored
`Features/` directory, then runs `swift test` in `e2e/`. Only `evaluation.feature` is implemented;
the other feature files are deliberately not copied, because CucumberSwift fails every step it has
no expression for.

Do **not** run `swift test` inside `e2e/` directly on a fresh clone: CucumberSwift asserts that it
found at least one `.feature` file, so a missing one traps the test process. `--filter` is no use
either, because CucumberSwift builds its test cases at runtime and SwiftPM finds none to match;
filter by tag with `CUCUMBER_TAGS=deprecated ./scripts/e2e` instead.

To bump the spec pin:

```shell
git -C spec fetch origin && git -C spec checkout <sha>
git add spec && git commit -m "chore: bump spec submodule"
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
