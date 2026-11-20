## 0.1.0-dev.0

First preview of the tools for apps that use [coil](https://pub.dev/packages/coil). Add it as a dev dependency. It needs Flutter 3.47 or later and a coil 0.1 pre-release.

 - `dart run coil_cli:eject` copies coil components into your app so you can change their look. It takes component names or `--all`, plus `--prefix`, `--rename` and `--library` to give the copies your names. It writes an app library that exports coil minus the ejected names, plus the copies.
 - `dart run coil_cli:update` merges coil's later changes into the copies with `git merge-file`, against the pristine base in `.coil/base/`. A new name upstream gets your prefix in every ejected component. Conflicts get standard markers.
 - `package:coil_cli/testing.dart` has `expectCoilPattern` and `CoilPattern`, which check an ejected copy's semantics, keyboard and focus behavior in tests.
 - `package:coil_cli/coil_cli.dart` reads a coil package's components and their exports, for tools such as coil's docs generator.
 - Eject and update read only coil, the ejected copies, their bases and the app library. They follow no links, so `.fvm`, `build/`, `Pods` and plugin symlinks are skipped.
