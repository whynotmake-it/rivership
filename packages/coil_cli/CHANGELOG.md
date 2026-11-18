## 0.0.1-dev.0

Unreleased.

- `dart run coil_cli:eject` and `dart run coil_cli:update`, moved out of
  coil so its dependencies stay runtime-only. Eject takes components or
  `--all`, plus `--prefix`, `--rename` and `--library`; update merges
  coil's changes into the copies with `git merge-file`.
- `expectCoilPattern` and `CoilPattern` in `package:coil_cli/testing.dart`,
  moved from `package:coil/testing.dart`.
- `package:coil_cli/coil_cli.dart` reads a coil package's components and
  their exports, for tools such as coil's docs generator.
- `coil_cli:update` gives a name new upstream the app's prefix in every
  ejected component, not only in the one that declares it.
- Eject and update re-read only coil, the ejected copies, their bases and
  the app library, and follow no links, instead of every Dart file under
  the app (`.fvm`, `build/`, `Pods`, plugin symlinks).
