<!-- markdownlint-disable MD033 -->
<!-- x-hide-in-docs-start -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/white/openfeature-horizontal-white.svg" />
    <img align="center" alt="OpenFeature Logo" src="https://raw.githubusercontent.com/open-feature/community/0e23508c163a6a1ac8c0ced3e4bd78faafe627c7/assets/logo/horizontal/black/openfeature-horizontal-black.svg" />
  </picture>
</p>

<h2 align="center">OpenFeature iOS SDK</h2>

<!-- x-hide-in-docs-end -->
<!-- The 'github-badges' class is used in the docs -->
<p align="center" class="github-badges">
<!-- TODO: update this with the version of the SDK your implementation supports -->

  <a href="https://github.com/open-feature/spec/releases/tag/v0.8.0">
    <img alt="Specification" src="https://img.shields.io/static/v1?label=specification&message=v0.8.0&color=yellow&style=for-the-badge" />
  </a>
  <!-- x-release-please-start-version -->

  <a href="https://github.com/open-feature/swift-sdk/releases/tag/0.3.1">
    <img alt="Release" src="https://img.shields.io/static/v1?label=release&message=v0.3.1&color=blue&style=for-the-badge" />
  </a>

  <!-- x-release-please-end -->
  <br/>
  <img alt="Status" src="https://img.shields.io/badge/lifecycle-alpha-a0c3d2.svg" />
</p>
<!-- x-hide-in-docs-start -->

[OpenFeature](https://openfeature.dev) is an open specification that provides a vendor-agnostic, community-driven API for feature flagging that works with your favorite feature flag management tool or in-house solution.

<!-- x-hide-in-docs-end -->
## 🚀 Quick start

### Requirements

This SDK supports the following Apple platforms:
- **iOS 14+**
- **macOS 11+**
- **watchOS 7+**
- **tvOS 14+**

The SDK is built with Swift 5.5+ and uses only Foundation and Combine frameworks, making it suitable for all Apple platform contexts including mobile, desktop, wearable, and TV applications.

### Install

#### Xcode Dependencies

You have two options, both start from File > Add Packages... in the code menu.

First, ensure you have your GitHub account added as an option (+ > Add Source Control Account...). You will need to create a [Personal Access Token](https://github.com/settings/tokens) with the permissions defined in the Xcode interface.

1. Add as a remote repository
    * Search for `git@github.com:open-feature/swift-sdk.git` and click "Add Package"
2. Clone the repository locally
    * Clone locally using your preferred method
    * Use the "Add Local..." button to select the local folder

**Note:** Option 2 is only recommended if you are making changes to the client SDK.

#### Swift Package Manager

If you manage dependencies through SPM, in the dependencies section of Package.swift add:

<!---x-release-please-start-version-->
```swift
.package(url: "git@github.com:open-feature/swift-sdk.git", from: "0.3.1")
```
<!---x-release-please-end-->

and in the target dependencies section add:
```swift
.product(name: "OpenFeature", package: "swift-sdk"),
```

#### CocoaPods

If you manage dependencies through CocoaPods, add the following to your Podfile:

```ruby
pod 'OpenFeature', '~> 0.3.0'
```

Then, run:

```bash
pod install
```

### iOS Usage

```swift
import OpenFeature

Task {
    let provider = CustomProvider()
    // configure a provider, wait for it to complete its initialization tasks
    await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

    // get a bool flag value
    let client = OpenFeatureAPI.shared.getClient()
    let flagValue = client.getBooleanValue(key: "boolFlag", defaultValue: false)
}
```

## 🌟 Features


| Status  | Features                        | Description                                                                                                                        |
| ------  | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| ✅      | [Providers](#providers)         | Integrate with a commercial, open source, or in-house feature management tool.                                                     |
| ✅      | [Targeting](#targeting)         | Contextually-aware flag evaluation using [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context). |
| ✅      | [Hooks](#hooks)                 | Add functionality to various stages of the flag evaluation life-cycle.                                                             |
| ❌      | [Tracking](#tracking)           | Associate user actions with feature flag evaluations.                                                                              |
| ❌      | [Logging](#logging)             | Integrate with popular logging packages.                                                                                           |
| ❌      | [Named clients](#named-clients) | Utilize multiple providers in a single application.                                                                                |
| ✅      | [Eventing](#eventing)           | React to state changes in the provider or flag management system.                                                                  |
| ❌      | [Shutdown](#shutdown)           | Gracefully clean up a provider during application shutdown.                                                                        |
| ✅      | [Extending](#extending)         | Extend OpenFeature with custom providers and hooks.                                                                                |

<sub>Implemented: ✅ | In-progress: ⚠️ | Not implemented yet: ❌</sub>

### Providers

[Providers](https://openfeature.dev/docs/reference/concepts/provider) are an abstraction between a flag management system and the OpenFeature SDK.
Look [here](https://openfeature.dev/ecosystem?instant_search%5BrefinementList%5D%5Btype%5D%5B0%5D=Provider&instant_search%5BrefinementList%5D%5Btechnology%5D%5B0%5D=Swift) for a complete list of available providers.
If the provider you're looking for hasn't been created yet, see the [develop a provider](#develop-a-provider) section to learn how to build it yourself.

Once you've added a provider as a dependency, it can be registered with OpenFeature like this:

```swift
await OpenFeatureAPI.shared.setProviderAndWait(provider: MyProvider())
```

> Asynchronous API that doesn't wait is also available

### Targeting

Sometimes, the value of a flag must consider some dynamic criteria about the application or user, such as the user's location, IP, email address, or the server's location.
In OpenFeature, we refer to this as [targeting](https://openfeature.dev/specification/glossary#targeting).
If the flag management system you're using supports targeting, you can provide the input data using the [evaluation context](https://openfeature.dev/docs/reference/concepts/evaluation-context).

```swift
// Configure your evaluation context and pass it to OpenFeatureAPI
let ctx = MutableContext(
    targetingKey: userId,
    structure: MutableStructure(attributes: ["product": Value.string(productId)]))
OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
```

### Hooks

[Hooks](https://openfeature.dev/docs/reference/concepts/hooks) allow for custom logic to be added at well-defined points of the flag evaluation life-cycle.
Look [here](https://openfeature.dev/ecosystem/?instant_search%5BrefinementList%5D%5Btype%5D%5B0%5D=Hook&instant_search%5BrefinementList%5D%5Btechnology%5D%5B0%5D=Swift) for a complete list of available hooks.
If the hook you're looking for hasn't been created yet, see the [develop a hook](#develop-a-hook) section to learn how to build it yourself.

Once you've added a hook as a dependency, it can be registered at the global, client, or flag invocation level.

```swift
// add a hook globally, to run on all evaluations
OpenFeatureAPI.shared.addHooks(hooks: ExampleHook())

// add a hook on this client, to run on all evaluations made by this client
val client = OpenFeatureAPI.shared.getClient()
client.addHooks(ExampleHook())

// add a hook for this evaluation only
_ = client.getValue(
    key: "key",
    defaultValue: false,
    options: FlagEvaluationOptions(hooks: [ExampleHook()]))
```
### Tracking

Tracking is not yet available in the iOS SDK.

### Logging

Logging customization is not yet available in the iOS SDK.

### Named clients

Support for named clients is not yet available in the iOS SDK.

### Eventing

Events allow you to react to state changes in the provider or underlying flag management system, such as flag definition changes, provider readiness, or error conditions.
Initialization events (`PROVIDER_READY` on success, `PROVIDER_ERROR` on failure) are dispatched for every provider.
Some providers support additional events, such as `PROVIDER_CONFIGURATION_CHANGED`.

Please refer to the documentation of the provider you're using to see what events are supported.

```swift
let cancellable = OpenFeatureAPI.shared.observe().sink { event in
    switch event {
    case ProviderEvent.ready:
        // ...
    default:
        // ...
    }
}
```

### Shutdown

A shutdown function is not yet available in the iOS SDK.

## Extending

### Develop a provider

To develop a provider, you need to create a new project and include the OpenFeature SDK as a dependency.
You'll then need to write the provider by implementing the `FeatureProvider` interface exported by the OpenFeature SDK.

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

    ...
}

```
> Built a new provider? [Let us know](https://github.com/open-feature/openfeature.dev/issues/new?assignees=&labels=provider&projects=&template=document-provider.yaml&title=%5BProvider%5D%3A+) so we can add it to the docs!

### Develop a hook

To develop a hook, you need to create a new project and include the OpenFeature SDK as a dependency.
Implement your own hook by conforming to the `Hook interface`.
To satisfy the interface, all methods (`Before`/`After`/`Finally`/`Error`) need to be defined.

```swift
class BooleanHook: Hook {
    typealias HookValue = Bool

    func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        // do something
    }

    func after<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]) {
        // do something
    }

    func error<HookValue>(ctx: HookContext<HookValue>, error: Error, hints: [String: Any]) {
        // do something
    }

    func finally<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        // do something
    }
}
```

> Built a new hook? [Let us know](https://github.com/open-feature/openfeature.dev/issues/new?assignees=&labels=hook&projects=&template=document-hook.yaml&title=%5BHook%5D%3A+) so we can add it to the docs!

<!-- x-hide-in-docs-start -->
## ⭐️ Support the project

- Give this repo a ⭐️!
- Follow us on social media:
  - Twitter: [@openfeature](https://twitter.com/openfeature)
  - LinkedIn: [OpenFeature](https://www.linkedin.com/company/openfeature/)
- Join us on [Slack](https://cloud-native.slack.com/archives/C0344AANLA1)
- For more, check out our [community page](https://openfeature.dev/community/)

## 🤝 Contributing

Interested in contributing? Great, we'd love your help! To get started, take a look at the [CONTRIBUTING](CONTRIBUTING.md) guide.

### Thanks to everyone who has already contributed

<a href="https://github.com/open-feature/swift-sdk/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=open-feature/swift-sdk" alt="Pictures of the folks who have contributed to the project" />
</a>

Made with [contrib.rocks](https://contrib.rocks).
<!-- x-hide-in-docs-end -->
