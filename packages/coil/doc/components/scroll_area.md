# ScrollArea

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/scroll_area.dart';
```

Exports `CoilEdgeFades`, `CoilScrollArea`, `CoilScrollAreaStyle`, `CoilScrollAreaTrack`, `CoilScrollbarVisibility`.

To change its look or composition, eject a copy into your app with `dart run coil:eject scroll_area` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## ScrollArea

- **Physics:** platform physics (§9.2).
- **Edge fades (`CoilScrollEdgeFade`):** each edge fades in as content scrolls away from it, up to 32, following the scroll direction (RTL, reversed lists). The amount springs on `fade`. The ramp is eased, not linear, so it has no visible start or end. Over a known solid background the fade is painted in that color on top; elsewhere it masks the content, which costs an offscreen layer.
- **Pointer scrollbar:** 4 wide, widening to 6 on hover; 2 from the edge and 4 from the ends; `foreground` 8 % (12 % hovered, 16 % dragging); radius full. It shows while scrolling or hovered and hides 600 ms later. The hide is `RawScrollbar`'s timed fade over the `fade` token's duration, not a spring: `RawScrollbar` owns that animation and exposes no way to drive it.
- **Touch:** a thin overlay bar in coil's colors (3 wide) that shows only while scrolling and can't be grabbed. Flutter draws no OS scrollbar, so this stands in for it.
- **Keyboard:** the viewport is focusable when it scrolls; arrows, Page and Home/End scroll; the focus ring is inset 1.
- **Don't:** nest scroll areas on the same axis.
