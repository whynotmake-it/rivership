# Card

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/card.dart';
```

Exports `CoilCard`, `CoilCardGroup`, `CoilCardGroupLayout`, `CoilCardStyle`, `CoilCardTrack`, `CoilCardVariant`.

To change its look or composition, eject a copy into your app with `dart run coil:eject card` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Card

- **Anatomy:** a container (surface 3 in light, 2 + hairline in dark; container radius) → [media] header (title role, description caption muted) → content → footer (actions); an optional dismiss ✕; an optional stretched action (the whole card is a link or button).
- **Variants:** `stacked` (media on top, full-bleed 16:9 image) and `inline` (media leading: a 32 tinted tile or an image 160 square).
- **Padding:** 16 (compact 12). Content and footer 12 below the header.
- **Groups:** one divided block with hairlines between cards, or `separated` (gap 8).
- **States:** a card with an action hovers (pointer) with the gliding highlight across a card grid; pressed `active` (touch); keyboard focus draws an inset ring.
- **Dismiss ✕:** pointer shows it on hover or focus-within; **touch always shows it**, 44 hit.
- **Card buttons:** small ghost buttons (28 pointer, 36 / 44 hit touch), caption semibold.
- **Motion:** highlight `quick`; dismiss exit is a blur-fade plus a height collapse on `standard`.
- **Do:** one primary action per card.
- **Don't:** nest cards.
