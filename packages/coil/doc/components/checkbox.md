# Checkbox

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/checkbox.dart';
```

Exports `CoilCheckbox`, `CoilCheckboxGlyph`, `CoilCheckboxGlyphBuilder`, `CoilCheckboxIndicator`, `CoilCheckboxStyle`, `CoilCheckboxTrack`.

To change its look or composition, eject a copy into your app with `dart run coil:eject checkbox` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Checkbox

- **Anatomy:** a box (1.5 px border); when checked, a bare tick with no box (FF's signature); a dash when null.
- **Sizes:** box 16 / 14 / 20 / 18, radius 5 / 4 / 6 / 5, glyph 18 / 16 / 22 / 20. Hit box 44 on touch. Inside a row, use `CoilCheckboxIndicator`, which has no hit box of its own.
- **States:**
  - unchecked: `border`; hover: foreground 40 %; invalid: destructive 50 %;
  - checked / indeterminate: border transparent; hover brings the 40 % border back;
  - disabled: 50 %.
  - High contrast draws the box around the tick.
- **API:** `value: bool?` + `tristate`. A tap cycles false → true → (null) → false.
- **Motion:** the tick draws on `fade` and retracts on `fadeExit`; check ↔ dash re-keys (old retracts, new draws); border on `fade`.
- **Keyboard:** Space toggles. Enter toggles only inside a choice card (Field).
- **Semantics:** `checked`, `mixed`, `enabled`, label from the Field.
- **Do:** use it for independent on/off in forms, with a visible label.
- **Don't:** use it for a setting that applies immediately (use Switch).
