# Button

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/button.dart';
```

Exports `CoilButton`, `CoilButtonStyle`, `CoilButtonTrack`, `CoilButtonVariant`.

To change its look or composition, eject a copy into your app with `dart run coil:eject button` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Button

- **Anatomy:** fill → [leading] label [trailing]; icon-only is square.
- **Sizes** (height · padding · gap):

  | | P | Pc | T | Tc |
  |---|---|---|---|---|
  | Labeled | 36 · 16 (12 next to icon) · 6 | 28 · 12/8 · 4 | 44 · 20/16 · 8 | 36 · 16/12 · 6, 44 hit |
  | Icon-only | 36 | 28 | 44 | 36 visual, 44 hit |

  The label is body semibold.
- **Variants:**

  | Variant | Rest | Hover | Pressed / selected | Label |
  |---|---|---|---|---|
  | primary | `foreground` | 90 % Oklab toward background | 80 % | `background` |
  | secondary | `tint` | `tintHover` | `tint` | foreground |
  | tertiary | clear, hairline | `hover` | `active` | foreground |
  | ghost | clear | `hover` | `active` | muted → foreground |
  | destructive | red 15 % (dark 20 %) | 25 % (30 %) | 15 % | `redLabel` |

- **States:**
  - `loading`: a spinner replaces the leading slot (or the icon) with the width locked, at full strength, `Semantics(value: 'Loading')`.
  - `selected`: held pressed colors, for a menu trigger while its menu shows.
  - Disabled: 50 %.
- **Motion:** fill and label colors on `fade`; press collapse on `quick` (release on `standard`); icon weight on `fade`; leading/loading swap with the blur-fade on `quick`.
- **Keyboard:** Enter or Space activates.
- **Do:** one primary per view; destructive actions as `destructive` with a confirm.
- **Don't:** scale on press; ripple; a solid red button; two primaries side by side.
