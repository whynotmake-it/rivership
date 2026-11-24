# coil_cli

CLI and test utilities for apps using [Coil](https://pub.dev/packages/coil). Copy any Coil component into your app to customize its look, merge upstream Coil updates back into your local copies, and verify that your customized components still follow Coil's interaction and accessibility patterns.

Add it as a dev dependency so none of it ships in your app:

```sh
flutter pub add dev:coil_cli
```

## Ejecting and updating components

```sh
dart run coil_cli:eject --list                 # List all components (* marks ejected ones)
dart run coil_cli:eject button dialog          # Copy components into lib/coil/
dart run coil_cli:eject --all --prefix Acme    # Copy everything renamed as AcmeButton, etc.
dart run coil_cli:update --dry-run             # Preview upstream changes before merging
dart run coil_cli:update                       # Three-way merge upstream updates into local copies
```

- **Eject:** Copies each selected component's files into your app, rewrites their imports to Coil's public libraries, and generates an app barrel (`lib/coil.dart`) that exports Coil minus the ejected symbols plus your local copies. Components ejected together or separately automatically reference each other's local copies.
- **Renaming:** On your first eject, pass `--prefix`, `--rename From=To`, or `--library` to use your own naming. Renaming uses the Dart analyzer and updates declarations, references, `[Name]` doc links, and file names without touching string literals, private identifiers, members, or parameters.
- **Updating:** Runs `git merge-file` per file against the original snapshots saved in `.coil/base/`, applying your naming rules to the new upstream version before merging. Any conflicts receive standard git conflict markers and preserve their previous base snapshot. Requires `git` on your `PATH`.
- **Manifest:** `.coil/ejected.yaml` tracks the Coil version, rename rules, and ejected paths. Commit both `.coil/ejected.yaml` and `.coil/base/` to version control.

`coil_cli` locates Coil through your app's package config, so it always matches the Coil version your app resolved. See Coil's [`SKILL.md`](https://github.com/whynotmake-it/rivership/blob/main/packages/coil/SKILL.md) for the full workflow.

## Testing ejected components

```dart
import 'package:coil_cli/testing.dart';

await expectCoilPattern(tester, find.byType(AcmeButton), CoilPattern.button);
```

`expectCoilPattern` verifies a `CoilPattern`'s semantics, keyboard navigation, and focus behavior: `Tab` reaches the widget, keyboard focus shows the focus ring, a pointer press hides it, and the pattern's keyboard shortcuts work as expected.
