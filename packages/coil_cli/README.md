# coil_cli

Tools for apps that use [coil](../coil): eject a component into the app to change its look, merge coil's later changes into the copy, and check the copy's interaction patterns in tests. Add it as a dev dependency, so none of it ships with the app:

```sh
flutter pub add dev:coil_cli
```

## Eject and update

```sh
dart run coil_cli:eject --list                 # every component; * marks ejected ones
dart run coil_cli:eject button dialog          # copy them to lib/coil/
dart run coil_cli:eject --all --prefix Acme    # copy everything as AcmeButton, …
dart run coil_cli:update --dry-run             # what coil's new version would change
dart run coil_cli:update                       # three-way merge into every copy
```

- **Eject** copies a component's folder and public libraries and rewrites their imports to coil's public libraries. It also writes an app library (`lib/coil.dart`) that exports coil minus the ejected names, plus the copies. Components ejected together, or one after another, use each other's copies.
- **Names:** the first eject can set `--prefix`, `--rename From=To` and `--library`. The analyzer renames declarations, references, doc links and file names, never strings, private names, members or parameters.
- **Update** runs `git merge-file` per file against the pristine base in `.coil/base/`, after renaming coil's new version the same way. Conflicts get standard markers and keep their old base. It needs `git` on your PATH.
- **The manifest** `.coil/ejected.yaml` records the version, names and paths. Commit it with `.coil/base/`.

The CLI finds coil through your app's package config, so it works with whichever coil version the app resolved. coil's [`SKILL.md`](../coil/SKILL.md) covers the whole flow.

## Check an ejected copy

```dart
import 'package:coil_cli/testing.dart';

await expectCoilPattern(tester, find.byType(AcmeButton), CoilPattern.button);
```

`expectCoilPattern` checks one `CoilPattern`'s semantics, keyboard and focus rules: Tab reaches the widget, keyboard focus shows the ring, a pointer press hides it, and the pattern's keys work.

## Tests

`flutter test` in this package. `test/ejectable_test.dart` checks that every coil component can be ejected, and `test/eject/eject_app_test.dart` ejects all of them into a fresh app, analyzes it and renders the copies.
