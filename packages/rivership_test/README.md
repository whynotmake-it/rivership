# Rivership Test

[![Pub Version](https://img.shields.io/pub/v/rivership_test)](https://pub.dev/packages/rivership_test)
[![lintervention_badge]][lintervention_link]
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

A package containing testing utilities to accompany the rivership package.

## Installation 💻

Add it as a dev dependency:

```sh
flutter pub add dev:rivership_test
```

## What's included 📦

- `MockProviderListener` is a mocktail mock you pass to `ref.listen`, so you can `verify` the changes a provider emits.
- `isShuffled(other)` matches an iterable that has the same elements as `other` in a different order.
- It re-exports `flutter_test`, `mocktail`, `fake_async` and `clock`, so one import covers a test file.

---


[dart_install_link]: https://dart.dev/get-dart
[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[mason_link]: https://github.com/felangel/mason
[very_good_ventures_link]: https://verygood.ventures

[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40