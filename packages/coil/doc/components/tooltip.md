# Tooltip

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/tooltip.dart';
```

Exports `CoilTooltip`, `CoilTooltipBubble`, `CoilTooltipGroup`.

To change its look or composition, eject a copy into your app with `dart run coil:eject tooltip` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Tooltip

- **Anatomy:** an inverted bubble (`foreground` fill, caption text in `background`), padding 8×4 (~24 high), item radius, 8 from the trigger.
- **Pointer:**
  - opens after 200 ms of hover, or immediately on keyboard focus;
  - closes on leave, blur, Esc or pointer-down;
  - within 300 ms of another closing, it opens without delay;
  - **TooltipGroup:** one bubble glides between adjacent triggers on `quick`, morphing its width and crossfading the label on `fade`.
- **Touch:**
  - Android: long-press on icon-only buttons shows it above the finger (8 + 24), held while pressed and faded on release. It never fires the button.
  - iOS: none by default.
  - If the element has a context menu, long-press opens the menu instead.
- **Motion:** blur-fade + a 4 px slide out from the trigger (it starts 4 px closer and moves away) on `quick`, out on `quickExit`.
- **Semantics:** the text is also `Semantics(tooltip:)`.
- **Don't:** put required information in a tooltip; tooltip a labeled button.
