# Reveal

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/reveal.dart';
```

Exports `CoilReveal`, `CoilRevealPreset`, `CoilRevealSteps`, `CoilRevealTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject reveal` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Reveal

- **What it is:** a screen settling in. `CoilReveal` blur-fades its children in one after another on first build (`CoilBlurFade`). Rebuilds don't replay it, and nothing moves on scroll. A Reveal that's built anew (a new route, a lazy list building it again) plays again, as a fresh subtree should.
- **Presets:**

  | Preset | Step | Motion (in / out) | Look when hidden |
  |---|---|---|---|
  | `product` (default) | `stagger` (60 ms) | `fade` / `fadeExit` | blur 4, scale 0.96 |
  | `subtle` | ⅔ `stagger` (40 ms) | `fade` / `fadeExit` | blur 4, scale 0.96 |
  | `landing` | 5⁄3 `stagger` (100 ms) | `gentle` / `gentleExit` (the original's `slow`) | blur 4, scale 0.94, 12 px below |

  `landing` is for the part of a landing page on screen at load.
- **Steps:** child 1 at once, then one step per child. `CoilRevealSteps.blocks` (a screen's panels) staggers 3 steps and brings the rest in with the 4th; `.items` (a list's rows) staggers 7.
- **Hiding:** `visible: false` hides the children with the same stagger, in the same order (as the original's `reveal-out` keeps each child's delay), on the exit motion. `true` reveals them again. A flip halfway turns each child around from where it is. Hidden children stay mounted but take no pointer, focus or semantics.
- **Loading:** the original's `reveal-swap` is `CoilSkeletonSwitcher`. Put the loaded content in a `CoilReveal` with `.items`, and its rows arrive one by one.
- **Reduced motion:** `stagger` is zero, and the blur-fade only fades. Every child fades in or out at once, on `fade` / `fadeExit`, `landing` included.
- **Do:** wrap the main column or a list. Keep headers, sidebars and footers outside, so the frame stays still.
- **Don't:** reveal on scroll. The landing page's scroll-driven reveal is cut.
