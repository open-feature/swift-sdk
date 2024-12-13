# Changelog

## [0.2.1](https://github.com/open-feature/swift-sdk/compare/0.2.0...0.2.1) (2024-12-13)


### 🐛 Bug Fixes

* remove compilation warnings ([#47](https://github.com/open-feature/swift-sdk/issues/47)) ([a21214e](https://github.com/open-feature/swift-sdk/commit/a21214eb7d6ad7b5942d41097dd776032d635827))

## [0.2.0](https://github.com/open-feature/swift-sdk/compare/0.1.0...0.2.0) (2024-07-08)


### ⚠ BREAKING CHANGES

* Add support for Flag Metadata ([#43](https://github.com/open-feature/swift-sdk/issues/43))

### 🐛 Bug Fixes

* Make HookContext properties public ([#45](https://github.com/open-feature/swift-sdk/issues/45)) ([003bbb6](https://github.com/open-feature/swift-sdk/commit/003bbb66ec493664f5810334f32411014a2195a8))


### ✨ New Features

* Add support for Flag Metadata ([#43](https://github.com/open-feature/swift-sdk/issues/43)) ([7256a3c](https://github.com/open-feature/swift-sdk/commit/7256a3cf7fb62e1ab3c2671ca471d8e30f3c522f))
* add support for provider fatal error ([#44](https://github.com/open-feature/swift-sdk/issues/44)) ([09d2871](https://github.com/open-feature/swift-sdk/commit/09d28719037b00f8bc48885270c88c93f9342644))


### 🧹 Chore

* **deps:** update dependency apple/swift-format to v510 ([#37](https://github.com/open-feature/swift-sdk/issues/37)) ([84e6f11](https://github.com/open-feature/swift-sdk/commit/84e6f11fe766bc472a9c0a086bb9befb3a4dbec8))

## [0.1.0](https://github.com/open-feature/swift-sdk/compare/0.0.2...0.1.0) (2024-02-02)


### ⚠ BREAKING CHANGES

* Add EventHandler + Combine ([#29](https://github.com/open-feature/swift-sdk/issues/29))

### 🐛 Bug Fixes

* setProviderAndWait does not hang on ProviderError ([#35](https://github.com/open-feature/swift-sdk/issues/35)) ([5661080](https://github.com/open-feature/swift-sdk/commit/566108007c57a250eac69828f6bdc58d4c1e7c1d))


### ✨ New Features

* Add ProviderNotReady event ([#36](https://github.com/open-feature/swift-sdk/issues/36)) ([389f117](https://github.com/open-feature/swift-sdk/commit/389f117ed4c8612d557f5e854606504cc0fdf3c9))
* Add setProviderAndWait ([#30](https://github.com/open-feature/swift-sdk/issues/30)) ([3ce6b8d](https://github.com/open-feature/swift-sdk/commit/3ce6b8d7f14150c77b363df0af3ce41c0e80138d))


### 🧹 Chore

* **deps:** update actions/checkout action to v4 ([#18](https://github.com/open-feature/swift-sdk/issues/18)) ([eb0cd56](https://github.com/open-feature/swift-sdk/commit/eb0cd56d1b7c7bb24faf905e67361738731bbeb4))
* **deps:** update dependency apple/swift-format to v509 ([#21](https://github.com/open-feature/swift-sdk/issues/21)) ([5f12304](https://github.com/open-feature/swift-sdk/commit/5f12304fde5531b957d999a41a24e2122c0038c2))
* Smaller cleanup in tests ([#33](https://github.com/open-feature/swift-sdk/issues/33)) ([053dabc](https://github.com/open-feature/swift-sdk/commit/053dabcc8132ba8c48da0b5b313f13a2e9c21e06))


### 📚 Documentation

* add sections for logging, named providers, and shutdown ([#31](https://github.com/open-feature/swift-sdk/issues/31)) ([dc5876c](https://github.com/open-feature/swift-sdk/commit/dc5876cbf7d3f61f1db65572943f817a55fdaab9))
* Fix Installation documentation ([#27](https://github.com/open-feature/swift-sdk/issues/27)) ([5ddf45d](https://github.com/open-feature/swift-sdk/commit/5ddf45d367df20209c5f760c9a4330aeef1b2ee5)), closes [#25](https://github.com/open-feature/swift-sdk/issues/25)
* Update README to latest template ([#28](https://github.com/open-feature/swift-sdk/issues/28)) ([dbdd502](https://github.com/open-feature/swift-sdk/commit/dbdd5026e82c899f3858e14e1dd1547cd5f3f731))
* Update README.md ([#19](https://github.com/open-feature/swift-sdk/issues/19)) ([ec599ff](https://github.com/open-feature/swift-sdk/commit/ec599ff7228019286fdad66f4c38f78caf354025))


### 🔄 Refactoring

* Add EventHandler + Combine ([#29](https://github.com/open-feature/swift-sdk/issues/29)) ([dd122f7](https://github.com/open-feature/swift-sdk/commit/dd122f773ba23a1bc873c18cfbe6bf42f0665b02))

## [0.0.2](https://github.com/open-feature/swift-sdk/compare/v0.0.1...0.0.2) (2023-08-25)


### 🧹 Chore

* add version.txt ([ca61bdb](https://github.com/open-feature/swift-sdk/commit/ca61bdbeb4f71fc36ef1d8338bb764ad7cae108b))
* initial attempt to setup release please ([#11](https://github.com/open-feature/swift-sdk/issues/11)) ([e255ad8](https://github.com/open-feature/swift-sdk/commit/e255ad8876c2ad85e21bb1e17653aa59d58c5f10))
* **main:** release 0.0.2 ([#12](https://github.com/open-feature/swift-sdk/issues/12)) ([84db460](https://github.com/open-feature/swift-sdk/commit/84db46013c9ac76b6f4151d9cf4eaed062953758))
* reset version to 0 ([#13](https://github.com/open-feature/swift-sdk/issues/13)) ([e736459](https://github.com/open-feature/swift-sdk/commit/e736459bde510d7e6a11857cc0d4c81fd812e2ee))
* reset version to 0.0.1 ([e8a8374](https://github.com/open-feature/swift-sdk/commit/e8a83743847a30927de5262049e458c27d92ba05))
* Revert "chore: reset version to 0 ([#13](https://github.com/open-feature/swift-sdk/issues/13))" ([#15](https://github.com/open-feature/swift-sdk/issues/15)) ([c7ff441](https://github.com/open-feature/swift-sdk/commit/c7ff4412e6ac14a041c258e62ece8e3e99e5eba3))
* Update Release Please config ([#16](https://github.com/open-feature/swift-sdk/issues/16)) ([090e7e5](https://github.com/open-feature/swift-sdk/commit/090e7e54291a2fb9b2f7c5b72e68c79c2898bff6))


### 📚 Documentation

* refer to tag 0.0.1 in installation instructions ([#7](https://github.com/open-feature/swift-sdk/issues/7)) ([4545c99](https://github.com/open-feature/swift-sdk/commit/4545c991507a090176315fd79297c18cd2497d5f))
