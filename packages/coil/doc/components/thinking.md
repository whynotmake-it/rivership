# ThinkingSteps / ThinkingIndicator

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/thinking.dart';
```

Exports `CoilThinkingIndicator`, `CoilThinkingIndicatorStyle`, `CoilThinkingStep`, `CoilThinkingSteps`, `CoilThinkingStepsStyle`, `CoilThinkingStepsTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject thinking` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## ThinkingSteps / ThinkingIndicator

- **ThinkingSteps:**
  - Anatomy: a collapsible trigger ("Thought for 12s", body semibold when open, chevron) → a list of steps. A step is [icon or a 6 dot] title (body) → detail (caption muted) → sources (small solid badges, gap 6; a private badge until the Badge component lands) → an image (max 200 wide).
  - Width 320, max full.
  - Motion: collapse on `standard`; each new step grows its height on `gentle` and fades in after 80 ms; source badges scale 0.85 → 1 on `standard` with a 4 → 0 blur.
- **ThinkingIndicator:**
  - Anatomy: [glyph 20 / 18, muted] label (body muted). The width is reserved by the longest word.
  - Motion: the word cycles every 4 s; the incoming word rises 80 % → 0 and fades on `standard`, the outgoing word rises out on `standardExit`. The words are a parameter. Reduced motion: crossfade only, every 4 s.
  - Semantics: a live region (polite), announced once per change at most every 4 s.
