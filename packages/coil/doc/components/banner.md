# Banner

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/banner.dart';
```

Exports `CoilBanner`, `CoilBannerPlacement`, `CoilBannerStatus`, `CoilBannerStyle`, `CoilBannerTrack`, `CoilBannerVariant`.

To change its look or composition, eject a copy into your app with `dart run coil:eject banner` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Banner

- **Anatomy:** [status icon, one title line tall] title (body semibold) + description (body muted) → actions (Buttons, compact) → [dismiss ✕]. An optional tinted variant (status hue 8 % background).
- **Sizes:** padding 16 (compact 12; touch 16 with a 44 ✕ hit); icon 20 / 16 / 20; gap 12.
- **Placement:** `inline` (in flow) or `fixed` (top of the viewport, under the safe area).
- **Motion:**
  - Appear: the row height opens on `standard`; then the banner fades and scales 0.4 → 1 from the top on `gentle`, 80 ms later.
  - Dismiss: reverse on the exit tokens.
  - Touch: swipe horizontally to dismiss (with velocity).
  - Reduced motion: fade only.
- **Semantics:** a live region (polite; assertive for destructive); the ✕ is labeled "Dismiss".
- **Don't:** stack more than 2; use it for transient confirmations (use inline feedback).
