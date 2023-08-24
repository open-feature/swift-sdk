<!-- markdownlint-disable MD033 -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/white/openfeature-horizontal-white.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/black/openfeature-horizontal-black.svg">
    <img align="center" alt="OpenFeature Logo">
  </picture>
</p>

<h2 align="center">OpenFeature Swift SDK</h2>

![Status](https://img.shields.io/badge/lifecycle-alpha-a0c3d2.svg)

## 👋 Hey there! Thanks for checking out the OpenFeature Swift SDK

### What is OpenFeature?

[OpenFeature][openfeature-website] is an open standard that provides a vendor-agnostic, community-driven API for feature flagging that works with your favorite feature flag management tool.

### Why standardize feature flags?

Standardizing feature flags unifies tools and vendors behind a common interface which avoids vendor lock-in at the code level. Additionally, it offers a framework for building extensions and integrations and allows providers to focus on their unique value proposition.

## 🔍 Requirements

- The minimum iOS version supported is: `iOS 14`.

Note that this library is intended to be used in a mobile context, and has not been evaluated for use in other type of applications (e.g. server applications, macOS, tvOS, watchOS, etc.).

## 📦 Installation

### Xcode Dependencies

You have two options, both start from File > Add Packages... in the code menu.

First, ensure you have your GitHub account added as an option (+ > Add Source Control Account...). You will need to create a [Personal Access Token](https://github.com/settings/tokens) with the permissions defined in the Xcode interface.

1. Add as a remote repository
    * Search for `git@github.com:open-feature/swift-sdk.git` and click "Add Package"
2. Clone the repository locally
    * Clone locally using your preferred method
    * Use the "Add Local..." button to select the local folder

**Note:** Option 2 is only recommended if you are making changes to the client SDK.

### Swift Package Manager

If you manage dependencies through SPM, in the dependencies section of Package.swift add:
```swift
.package(url: "git@github.com:open-feature/swift-sdk.git", from: "0.0.1")
```

and in the target dependencies section add:
```swift
.product(name: "OpenFeature", package: "openfeature-swift-sdk"),
```

## 🌟 Features

- Support for various backend [providers](https://openfeature.dev/docs/reference/concepts/provider)
- Easy integration and extension via [hooks](https://openfeature.dev/docs/reference/concepts/hooks)
- Bool, string, numeric, and object flag types
- [Context-aware](https://openfeature.dev/docs/reference/concepts/evaluation-context) evaluation

## 🚀 Usage

```swift
import OpenFeature

// Configure your custom `FeatureProvider` and pass it to OpenFeatureAPI
let customProvider = MyCustomProvider()
OpenFeatureAPI.shared.setProvider(provider: customProvider)

// Configure your evaluation context and pass it to OpenFeatureAPI
let ctx = MutableContext(
    targetingKey: userId,
    structure: MutableStructure(attributes: ["product": Value.string(productId)]))
OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)

// Get client from OpenFeatureAPI and evaluate your flags
let client = OpenFeatureAPI.shared.getClient()
let flagValue = client.getBooleanValue(key: "boolFlag", defaultValue: false)
```

Setting a new provider or setting a new evaluation context are synchronous operations. The provider might execute I/O operations as part of these method calls (e.g. fetching flag evaluations from the backend and store them in a local cache). It's advised to not interact with the OpenFeature client until the relevant event has been emitted (see events below).

Please refer to our [documentation on static-context APIs](https://github.com/open-feature/spec/pull/171) for further information on how these APIs are structured for the use-case of mobile clients.

### Events

Events allow you to react to state changes in the provider or underlying flag management system, such as flag definition changes, provider readiness, or error conditions.
Initialization events (`PROVIDER_READY` on success, `PROVIDER_ERROR` on failure) are emitted for every provider.
Some providers support additional events, such as `PROVIDER_CONFIGURATION_CHANGED`.
Please refer to the documentation of the provider you're using to see what events are supported and when they are emitted.

To register a handler for API level provider events, use the `OpenFeatureAPI` `addHandler(observer:selector:event:)` function. Event handlers can also be removed using the equivalent `removeHandler` function. `Client`s also provide add and remove functions for listening to that specific client. A `ProviderEvent` enum is defined to ease subscription.

Events can contain extra information in the `userInfo` dictionary of the notification. All events will contain a reference to the provider that emitted the event (under the `providerEventDetailsKeyProvider` key). Error events will also provide a reference to the underlying error (under the `providerEventDetailsKeyError` key). Finally, client specific events will contain a reference to the client (under the `providerEventDetailsKeyClient` key)

### Providers

To develop a provider, you need to create a new project and include the OpenFeature SDK as a dependency. This can be a new repository or included in the existing contrib repository available under the OpenFeature organization. Finally, you’ll then need to write the provider itself. This can be accomplished by implementing the `FeatureProvider` protocol exported by the OpenFeature SDK.

```swift
import OpenFeature

final class CustomProvider: FeatureProvider {
    var hooks: [any Hook] = []
    var metadata: ProviderMetadata = CustomMetadata()

    func initialize(initialContext: EvaluationContext?) async {
        // add context-aware provider initialisation
    }

    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async {
        // add necessary changes on context change
    }

    func getBooleanEvaluation(
        key: String,
        defaultValue: Bool,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Bool> {
        // resolve a boolean flag value
    }

    func getStringEvaluation(
        key: String,
        defaultValue: String,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<String> {
        // resolve a string flag value
    }

    func getIntegerEvaluation(
        key: String,
        defaultValue: Int64,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Int64> {
        // resolve an integer flag value
    }

    func getDoubleEvaluation(
        key: String,
        defaultValue: Double,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Double> {
        // resolve a double flag value
    }

    func getObjectEvaluation(
        key: String,
        defaultValue: Value,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Value> {
        // resolve an object flag value
    }
}

```

## ⭐️ Support the project

- Give this repo a ⭐️!
- Follow us on social media:
    - Twitter: [@openfeature](https://twitter.com/openfeature)
    - LinkedIn: [OpenFeature](https://www.linkedin.com/company/openfeature/)
- Join us on [Slack](https://cloud-native.slack.com/archives/C0344AANLA1)
- For more check out our [community page](https://openfeature.dev/community/)

## 🤝 Contributing

Interested in contributing? Great, we'd love your help! To get started, take a look at the [CONTRIBUTING](CONTRIBUTING.md) guide.

### Thanks to everyone that has already contributed

<a href="https://github.com/open-feature/swift-sdk/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=open-feature/swift-sdk" alt="Pictures of the folks who have contributed to the project" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

## 📜 License

[Apache License 2.0](LICENSE)

[openfeature-website]: https://openfeature.dev
