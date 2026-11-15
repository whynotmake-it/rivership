# CarouselDots

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/carousel_dots.dart';
```

Exports `CoilCarouselDots`, `CoilCarouselDotsLabels`, `CoilCarouselDotsStyle`, `CoilCarouselDotsTrack`, `CoilSlidePositionFormatter`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject carousel_dots` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## CarouselDots

- **Anatomy:** a row of 6 dots 12 apart. The current dot is a 24 pill, either solid or filling with progress. Track `foreground` 15 %, fill 40 %.
- **Pointer:** each dot has its own 18 round click target; the highlight glides across dots. For screen readers the row is still one adjustable control.
- **Touch:** the group is **one adjustable control**, 44 high. Tap or drag along it to scrub; swipe the carousel itself to page. Single dots don't get 44 boxes.
- **Motion:** pill width 6 ↔ 24 on `standard`; fill driven by progress. The dots never advance by themselves: autoplay belongs to the carousel that owns them, which stops it under reduced motion.
- **Semantics:** adjustable, "Slide 2 of 5".
