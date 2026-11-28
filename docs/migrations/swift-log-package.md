# Migrating the SwiftLog adapter from 0.7.x

**Breaking change on Swift 6.2+:** `OpenFeatureSwiftLog` now requires the `SwiftLog` package trait. Older toolchains keep their existing adapter configuration. Core logging APIs and behavior are unchanged. These instructions apply to a release containing this change; 0.7.0 does not support the trait.

## Core-only users

No source changes are needed. On Swift 6.2+, resolve dependencies again; SwiftLog is removed unless another consumer enables the trait or requires SwiftLog directly. Older toolchains continue resolving SwiftLog.

## Adapter users on Swift 6.2+

1. Use `// swift-tools-version: 6.2` or newer and add `traits: ["SwiftLog"]` to the OpenFeature package dependency.
2. Keep `.product(name: "OpenFeatureSwiftLog", package: "swift-sdk")` and `import OpenFeatureSwiftLog`. Selecting the product alone does not enable the trait.

Existing logger calls remain unchanged. See [Using swift-log](../../README.md#using-swift-log) for Xcode configuration and direct `Logging` dependencies.
