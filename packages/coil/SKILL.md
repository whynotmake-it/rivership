---
name: coil
description: Build Flutter UI with the coil design system, theme it, and eject components into the app to edit them. Use when code imports package:coil, or when asked to restyle, eject or update a coil component.
---

# Using coil

coil is a Flutter design system on Motor springs. Use components as they are and change them through the theme first. Eject a component only when the theme can't express the change.

Every file this skill points to ships with the installed coil version, under the package root (find it in `.dart_tool/package_config.json`). Start at `doc/llms.txt`.

## Use

```dart
import 'package:coil/coil.dart';

CoilButton(onPressed: save, child: const Text('Save'))
```

- Works under any `WidgetsApp`. No Material or Cupertino app is needed.
- Visible text and icons are `Widget` slots (`child`, `leading`, `label`). Pass `Text`, not `String`.
- Each component's API, sizes and states are in `doc/components/<name>.md`.

## Theme

Change things here before ejecting. Every layer below wraps a subtree.

- **App-wide:** `CoilTheme(data: CoilThemeData(...), child: app)`. Start from `CoilThemeData.light` or `.dark`.
- **Colors:** `CoilColors.fromSeed(brightness:, brand:, neutralHue:, neutralChroma:)`.
- **Shape:** `shape: CoilShape.rounded`, `.pill` or `.sharp`.
- **Size tier:** `tier: CoilTier.pointer` or `.touch`. By default it follows the platform.
- **Motion:** `motion: CoilMotion(...)` for the tokens, `trackMotions: {CoilSwitchTrack.thumb: ...}` for one track. Per instance, use the component's `motion:` and `motions:`.
- **One component type:** `theme.withComponentStyle(CoilButtonStyle(...))`. Per instance, use the `style:` parameter.
- **A subtree:** `CoilTheme.override(transform: (t) => t.copyWith(shape: .pill), child: ...)`.

## Eject

Eject copies a component's source into the app so you can change its look or composition. Hover, press, focus, keyboard and overlay behavior stay in coil's primitives, so fixes to them still arrive through `pub upgrade`.

```sh
dart run coil:eject --list          # every component; * marks ejected ones
dart run coil:eject button          # copy Button to lib/coil/button/
dart run coil:eject button --into lib/ui
dart run coil:eject button --force  # replace the copy, discarding edits
```

Eject writes:

- `lib/coil/button/`: the public library `button.dart` and its sources in `src/`.
- `lib/coil.dart`: the app library. It exports `package:coil/coil.dart` minus the ejected names, plus the copies.
- `.coil/ejected.yaml` and `.coil/base/`: the coil version and a pristine copy of each file, which are the merge base for updates.

After ejecting:

1. Replace `package:coil/coil.dart` imports with the app library (`package:<app>/coil.dart`). Otherwise the app keeps using coil's own component.
2. Commit `.coil/`.
3. Edit the copy. It imports only `package:coil/foundation.dart`, `primitives.dart` and other components' public libraries.

Other coil components keep using coil's version of an ejected one. For example, `CoilDialog` still builds coil's `CoilButton`.

## Update

```sh
dart run coil:update button --dry-run   # what would change, as a diff
dart run coil:update button             # or no name: every ejected component
```

Update needs `git` on PATH. It runs `git merge-file` per file, with the base from `.coil/base/`, coil's new version, and the app's copy:

- A clean merge applies, and that file's base and version advance.
- A conflict writes `<<<<<<< app` / `>>>>>>> coil <version>` markers into the copy. The base stays put, so after resolving, run update again. The exit code is 1 while files need attention.
- Files coil added are copied. Files coil removed are deleted, unless the app edited them.

## Test an ejected copy

```dart
import 'package:coil/testing.dart';

await expectCoilPattern(tester, find.byType(CoilButton), CoilPattern.button);
```

`expectCoilPattern` checks semantics, keyboard and focus for one `CoilPattern`. It checks the copy, so run it after editing. Import `testing.dart` only from tests.
