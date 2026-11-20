# ThinkingSteps / ThinkingIndicator

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/thinking.dart';
```

Exports `CoilThinkingIndicator`, `CoilThinkingIndicatorStyle`, `CoilThinkingStep`, `CoilThinkingSteps`, `CoilThinkingStepsStyle`, `CoilThinkingStepsTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject thinking` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## ThinkingSteps / ThinkingIndicator

- **ThinkingSteps:**
  - Anatomy: a collapsible trigger ("Thought for 12s", body semibold when open, chevron) → a list of steps (panel padding 4 top, 12 bottom). A step (padding 8 × 6) is [icon or a 6 dot, in a one-icon square centered on the title's first line] title (body, semibold) → detail (body muted, 4 below) → sources (small solid badges, 8 below, gap 6; a private badge until the Badge component lands) → an image (max 200 wide, 8 below).
  - Connector (FF's step rail): every step but the last draws a 1 px line in `border` @ 60 %, centered under its glyph, from 4 below the glyph's square to the bottom of the step's content. It runs beside the detail, sources and image, so a one-line step shows none. It is part of the step's layout, so it follows wrapping, text scale and RTL, and is revealed with the step's height as the step grows in. When a step stops being the last, its connector fades in on `fade`. Color, width and gap are style fields.
  - Width 320, max full.
  - Motion: collapse on `standard`; each new step grows its height on `gentle` and fades in after 80 ms; source badges scale 0.85 → 1 on `standard` with a 1.5 → 0 blur.
- **ThinkingIndicator:**
  - Anatomy: [glyph 20 / 18, muted] label (body muted). The width is reserved by the longest word.
  - Motion: the word cycles every 4 s; the incoming word rises 80 % → 0 and fades on `standard`, the outgoing word rises out on `standardExit`. The words are a parameter. Reduced motion: crossfade only, every 4 s.
  - Semantics: a live region (polite), announced once per change at most every 4 s.
