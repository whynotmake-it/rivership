# Skeleton

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/skeleton.dart';
```

Exports `CoilSkeleton`, `CoilSkeletonRegion`, `CoilSkeletonStyle`, `CoilSkeletonSwitcher`, `CoilSkeletonText`, `CoilSkeletonTrack`.

To change its look or composition, eject a copy into your app with `dart run coil:eject skeleton` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Skeleton

- **Anatomy:** a block in `hover` tint at the item radius (text lines: line-box height × 0.6, full radius).
- **Motion:** after a 160 ms grace period it fades in over `fade`, then pulses opacity 1 → 0.5 → 1 every 2 s. Reduced motion keeps the grace and the fade, and drops the pulse.
- **Switching:** `CoilSkeletonSwitcher(loading:)` stacks the skeleton and the content in one cell and cross-fades them (`fade` in, `fadeExit` out), so the space is never empty. Skeletons shown first keep the grace period, so content that lands within it replaces them before they show. Skeletons that replace content on screen show at once. To swap without a fade, set the `swap` track to `Motion.instant()`.
- **Semantics:** excluded. The loading region carries `Semantics(label: 'Loading', liveRegion)`.
- **Do:** match the final layout's line count and widths. Text lines vary between 55 and 82 % of the width.
- **Don't:** shimmer.
