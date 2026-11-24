# Rivership Test

[![Pub Version](https://img.shields.io/pub/v/rivership_test)](https://pub.dev/packages/rivership_test)
[![lints by lintervention][lintervention_badge]][lintervention_link]
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

Testing utilities to accompany the `rivership` package.

## Installation

Add it as a dev dependency:

```sh
flutter pub add dev:rivership_test
```

## What's included

- `MockProviderListener` is a mocktail mock you pass to `ref.listen` so you can `verify` the changes a provider emits.
- `isShuffled(other)` matches an iterable that has the same elements as `other` in a different order.
- Re-exports `flutter_test`, `mocktail`, `fake_async`, and `clock` so one import covers a test file.

[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40