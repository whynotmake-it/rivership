# coil_glass

Liquid glass for [coil](../coil), rendered with
[`liquid_glass_renderer`](https://pub.dev/packages/liquid_glass_renderer).
Exploration prototype: opt-in, in its own package. coil's default look
doesn't change.

Glass is the far end of coil's material scale (flat → raised → glass), and
it is a variant of things coil already has, not new components:

- `CoilButton(variant: .glass)` and `.glassProminent` (the one primary
  action, tinted with the brand). Capsules; icon buttons are circles.
- Every popover: `CoilDropdown`, `CoilContextMenu`, `CoilSelect`,
  `CoilCombobox`, `CoilDatePicker`, in denser glass so rows stay legible.

App code uses coil's components only. One widget turns the glass on:

```dart
CoilTheme(
  data: theme,
  child: CoilGlassScope(          // installs CoilGlassMaterial
    reduceTransparency: platformReduceTransparency,
    child: app,
  ),
)

// Anywhere below: plain coil.
CoilMaterialGroup(                // one layer; separate at rest
  child: Row(children: [
    CoilButton.icon(variant: .glass, onPressed: share, icon: shareIcon,
      semanticLabel: 'Share'),
    const SizedBox(width: 8),
    CoilDropdown(
      entries: [...],
      builder: (context, menu) => CoilButton.icon(variant: .glass,
        onPressed: menu.open, icon: moreIcon, semanticLabel: 'More'),
    ),
  ]),
)
```

## How it plugs into coil

coil has a small seam in `package:coil/foundation.dart` that imports no
renderer:

| coil | Job |
|---|---|
| `CoilMaterial` | Builds a surface for a `CoilSurfaceSpec` (role `control` or `popover`, emphasis `regular` or `prominent`, radius), or returns null to keep coil's own. `group()` renders a cluster as one. |
| `CoilMaterialScope` | Provides the material (an `InheritedTheme`, so popovers and routes keep it). |
| `CoilMaterialGroup` | Marks surfaces that float together. |
| `CoilButtonVariant.glass`, `.glassProminent` | Ask the material; without one they are coil's raised surface (brand fill for prominent). |
| `CoilPopoverSurface` | Asks the material first. |

This package fills it:

| coil_glass | Job |
|---|---|
| `CoilGlassScope` | Installs `CoilGlassMaterial`, shares one backdrop capture per frame among all glass below, and carries the mode (Reduce Transparency, pinned mode for previews). |
| `CoilGlassMaterial` | Control → a glass capsule with a touch glow that swells and stretches toward a drag (tinted when prominent). Popover → `CoilGlassStyle.dense` glass in a layer of its own, with a touch glow. Group → one `CoilGlassLayer` + `CoilGlassGroup`. |

Glass never merges at rest. A `CoilGlassGroup` keeps its blend at 0; while
one of its buttons is held, the blend rises to 5 px (theme `quick`), so a
button stretched toward a neighbor joins it, and on release it springs back
to 0 (theme `standard`). Keep buttons in a group 8 px or more apart, so a
plain press (×1.04 swell) doesn't join them. Reduced motion turns stretch
and glow off, and with them the blending.
| `CoilGlassStyle` | A coil component style: variant, Apple's tint slider (`tintAmount`), `wash` (coil's surface color mixed in), `refraction`, shadow, blend distance while held, touch glow (`glow`, `glowRadius`), solid fill. Set app-wide with `CoilThemeData.withComponentStyle`. |
| `CoilGlass`, `CoilGlassLayer`, `CoilGlassGroup`, `CoilOnGlass` | Building blocks for glass you compose yourself. |

## Fallbacks

`CoilGlassMode.glass` → `frosted` (the renderer's `FakeGlass`, picked
automatically on the web and on Skia) → `solid` (the material declines and
coil paints its raised surfaces: Reduce Transparency, high contrast).

## Requirements and status

- Full glass needs Impeller and Flutter GPU (`--enable-flutter-gpu`, or
  `FLTEnableFlutterGPU` / `EnableFlutterGPU` in the app manifest). iOS, macOS
  and Android render it; web renders `FakeGlass`.
- `liquid_glass_renderer` 1.0.0-dev.2 pins Dart `>=3.13.0 <3.14.0`. The
  workspace's Flutter (3.50, Dart 3.14) can't resolve it, so this package is
  **not a workspace member yet** and resolves on its own. To try it on Dart
  3.14, point a git-ignored `pubspec_overrides.yaml` at a copy of the
  renderer with the SDK bound relaxed:

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

The second renders the album screen on a phone and a desktop, light and
dark, with and without `CoilGlassScope`, menu closed and open, plus the
fallbacks and a frame sequence of a menu opening in `frames/` (encode with
`ffmpeg -framerate 30 -i frames/menu_light_%03d.png`; snaptest's video
recorder is too slow with real glass in flutter_tester).
