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

`e2e/` is a separate Swift package that runs the OpenFeature specification's shared Gherkin suite using [CucumberSwift](https://github.com/cucumberswift/CucumberSwift).

```shell
./scripts/e2e
```

That script initialises the [`open-feature/spec`](https://github.com/open-feature/spec) submodule,
copies `spec/specification/assets/gherkin/evaluation.feature` into the test target's `Features/` directory, then runs `swift test` in `e2e/`. Only `evaluation.feature` is implemented.

Do **not** run `swift test` inside `e2e/` directly on a fresh clone: CucumberSwift asserts that it
found at least one `.feature` file.

To bump the spec pin, fetch the specific commit: the submodule is `shallow = true`, so a plain
`git -C spec fetch origin` leaves the commit unreachable and the checkout fails.

```shell
git -C spec fetch --depth 1 origin <sha> && git -C spec checkout <sha>
git add spec && git commit -m "chore: bump spec submodule"
```

