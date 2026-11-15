# Switch

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/switch.dart';
```

Exports `CoilSwitch`, `CoilSwitchStyle`, `CoilSwitchTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject switch` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Switch

- **Anatomy:** track → thumb, plus an optional label. The whole row is the target.
- **Sizes:** see §4.2. The thumb is inset 2. Hover grows the thumb +2 (pointer only, into a pill). Press widens it +4 and flattens it −4 (+5 / −5 on touch). The labeled row's vertical padding is (row − track) / 2.
- **Colors:**
  - off: `accent`; on: `brand`;
  - hover shifts the track 10 % toward `overlay` (off) or 8 % toward black (on), in Oklab;
  - thumb white with `shadow(2)`;
  - the label is muted when off and foreground when on (pointer); always foreground on touch.
- **Motion** (tracks `CoilSwitchTrack.thumb` / `.squish` / `.tint`):
  - thumb on `standard`, squish on `quick`, tint on `fade`;
  - dragging sets the thumb directly and may overshoot 0.15 of the travel, stretching the track;
  - release decides by `x + v · 0.1 s` and animates with the release velocity.
- **Keyboard:** Space or Enter toggles. The focus ring hugs the track with a 2 px `background` gap.
- **Semantics:** `toggled`, label.
- **Haptic:** iOS `selectionClick` when the value flips mid-drag.
- **Do:** use it for settings that apply immediately.
- **Don't:** use it in forms that need Submit; don't copy iOS's 51×31.
