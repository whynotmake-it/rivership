# coil_glass

Liquid glass for [coil](../coil), rendered with
[`liquid_glass_renderer`](https://pub.dev/packages/liquid_glass_renderer).
Exploration prototype: opt-in, in its own package, and coil's default look
doesn't change.

Glass is the far end of coil's material scale (flat → raised → glass). It
belongs to the **floating control layer**: tab bars, toolbars, sidebars that
float over content, menus, sheets and one or two floating actions. Content
(cards, lists, messages, fields in a form) stays coil-flat.

```dart
import 'package:coil_glass/coil_glass.dart';

CoilGlassBackdrop(            // one backdrop capture for the whole screen
  child: Stack(children: [
    const Content(),
    Positioned(
      left: 16, right: 16, bottom: 16,
      child: CoilGlassLayer(  // one render pass for this group of chrome
        child: CoilGlassGroup( // neighbors melt into each other
          child: Row(children: [
            Expanded(
              child: CoilGlassTabBar<Tab>(
                tabs: [...],
                value: tab,
                onChanged: setTab,
              ),
            ),
            const SizedBox(width: 10),
            CoilGlass(
              shape: CoilGlassShape.circle,
              response: CoilGlassResponse.stretch,
              child: searchButton,
            ),
          ]),
        ),
      ),
    ),
  ]),
)
```

| Widget | Job |
|---|---|
| `CoilGlassBackdrop` | Shares one capture of the content among every glass layer below (a `BackdropGroup`). |
| `CoilGlassLayer` | One backdrop pass and one set of optics for a group of chrome. Settings come from the coil theme (light/dark) and `CoilGlassStyle`. |
| `CoilGlassGroup` | Melts the shapes inside when they come within `blend` px. |
| `CoilGlass` | One shape: `container` (theme radius), `pill` or `circle`. Its child sits in `CoilOnGlass`. |
| `CoilOnGlass` | A theme override that adapts unchanged coil components to glass (platters instead of fills). |
| `CoilGlassTabBar` | Tab bar / segmented control whose selection lifts into a clear glass lens while it travels. |
| `CoilGlassStyle` | A coil component style: variant (`regular`, `clear`, `tinted`), Apple's tint slider, shadow, blend, solid fill. Set app-wide with `CoilThemeData.withComponentStyle`. |
| `CoilGlassScope` | `reduceTransparency` (Flutter has no flag for it yet) and a pinned `CoilGlassMode`. |

## Fallbacks

`CoilGlassMode.glass` → `frosted` (the renderer's `FakeGlass`, picked
automatically on the web and on Skia) → `solid` (coil's raised `CoilSurface`,
for Reduce Transparency and high contrast).

## Requirements and status

- Full glass needs Impeller and Flutter GPU (`--enable-flutter-gpu`, or
  `FLTEnableFlutterGPU` / `EnableFlutterGPU` in the app manifest). iOS, macOS
  and Android render it; web renders `FakeGlass`.
- `liquid_glass_renderer` 1.0.0-dev.2 pins Dart `>=3.13.0 <3.14.0`. The
  workspace's Flutter (3.50, Dart 3.14) can't resolve it, so this package is
  **not a workspace member yet** and resolves on its own. To try it on Dart
  3.14, put a copy of the renderer with the SDK bound relaxed next to it in a
  git-ignored `pubspec_overrides.yaml`:

  ```yaml
  dependency_overrides:
    liquid_glass_renderer:
      path: /path/to/liquid_glass_renderer   # sdk bound relaxed to <3.15.0
    motor: {path: ../motor}
    motor_widgets: {path: ../motor_widgets}
    stupid_simple_sheet: {path: ../stupid_simple_sheet}
  ```

  (Overrides in `pubspec_overrides.yaml` replace the pubspec's, so repeat
  `motor` there.) Once upstream widens the bound, add the package to the
  workspace and drop the overrides.

## Tests and visuals

```sh
flutter test                                      # behavior, FakeGlass
flutter test --enable-impeller --enable-flutter-gpu \
  --dart-define=COIL_GLASS_VISUALS=$PWD/visuals test/visuals_test.dart
```

The second renders every variant on a phone and a desktop, light and dark,
with real glass, plus a frame sequence of the morphing selection in
`frames/` (encode with `ffmpeg -framerate 30 -i frames/morph_light_%03d.png`;
snaptest's video recorder is too slow with real glass in flutter_tester).
