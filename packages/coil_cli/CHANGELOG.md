## 0.1.0-dev.0

First preview of `coil_cli`, the companion CLI and test toolkit for [Coil](https://pub.dev/packages/coil). Add it as a dev dependency. Requires Flutter 3.47 or later and a Coil 0.1 pre-release.

- **FEAT**: `dart run coil_cli:eject` copies selected Coil components (or `--all`) into your app for local customization, rewrites imports to Coil's public libraries, supports `--prefix`, `--rename`, and `--library` via the Dart analyzer, and generates an app barrel (`lib/coil.dart`).
- **FEAT**: `dart run coil_cli:update` three-way merges upstream Coil updates into ejected copies using `git merge-file` against pristine snapshots in `.coil/base/` (with `--dry-run` preview and automatic renaming).
- **FEAT**: `package:coil_cli/testing.dart` exports `expectCoilPattern` and `CoilPattern` to verify semantics, keyboard navigation, and focus behavior on ejected components.
- **FEAT**: `package:coil_cli/coil_cli.dart` exposes programmatic component and export inspection APIs.
