# End-to-end tests

Runs the OpenFeature specification's shared [`evaluation.feature`](https://github.com/open-feature/spec/blob/main/specification/assets/gherkin/evaluation.feature)
against `InMemoryProvider` using [CucumberSwift](https://github.com/cucumberswift/CucumberSwift),
driving the public `OpenFeatureAPI` and `Client` API with no mocks or stubs.

Run it from the repository root:

```shell
./scripts/e2e
```

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for details, and `Tests/OpenFeatureE2ETests/Steps/EvaluationPatterns.swift`
for the step-to-pattern mapping.
