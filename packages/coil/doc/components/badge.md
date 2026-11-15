# Badge

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/badge.dart';
```

Exports `CoilBadge`, `CoilBadgeColor`, `CoilBadgeStyle`, `CoilBadgeVariant`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject badge` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Badge

- **Anatomy:** [dot 7 (6 compact)] label (micro/caption).
- **Sizes:** P 24 high, padding 10, caption, gap 6. Compact: 20, padding 8, micro, gap 4. **No touch bump.** A badge isn't interactive.
- **Variants:**
  - `solid`: the hue at 15 % into the background, foreground text; gray uses `accent`.
  - `dot`: hairline outline, foreground text, colored dot.
  - `ghost`: no outline, no padding, inherits text color.
  - Colors: gray (default), brand, and the Tailwind-500 hues (red … rose).
- **Shape:** item radius, `pill` → full.
- **Motion:** none. When a host adds one (ThinkingSteps sources), scale 0.85 → 1 + fade on `standard`.
- **Semantics:** plain text; the dot is excluded.
- **Do:** status and categories.
- **Don't:** make it tappable; use a Chip-like Button instead.
