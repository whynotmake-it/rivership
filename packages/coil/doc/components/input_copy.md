# InputCopy

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/input_copy.dart';
```

Exports `CoilInputCopy`, `CoilInputCopyAlign`, `CoilInputCopyLabels`, `CoilInputCopyStyle`, `CoilInputCopyTrack`, `CoilInputCopyVariant`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject input_copy` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## InputCopy

- **Anatomy:** a read-only row (monospace value, truncated) plus a copy action: `icon` or `button` ("Copy"), on the trailing side or with `align: start`. The action always shows: without an `icon`, it is the theme's `copy` icon (§11), else coil's drawn copy glyph (two sheets). Label it with a Field: a tap on the label copies.
- **Sizes:** row = `controlHeight`, padding `controlPaddingX`.
- **States:**
  - idle;
  - hover (pointer): the value gets a `brand` 20 % mark and the action turns foreground;
  - after a copy: `copied` (check) or `failed` (× in destructive) for 2 s after the last copy, then idle. Any failure to set the clipboard counts as `failed`, not only a platform error.
  - Copying again while the result shows animates nothing and only restarts the 2 s. Copying while the result leaves turns it around from where it is (no restart, the check stays drawn). This is `CoilCopyController` plus `CoilCopySwitcher`, the one state machine every copy affordance uses.
  - The button label is not reserved: the row springs between the labels' real widths as "Copy" becomes "Copied" and back.
- **Feedback:** **inline on every platform.** The icon swaps to a check (the theme's `check`, or a drawn one; `failed` for an ×) and the button label reads "Copied". On iOS and Android also `selectionClick`. A pointer tooltip ("Copy to clipboard") is optional extra, never the only feedback.
- **Motion:** icon swap: two icon presences crossing (§11), in on `quick`, out on `quickExit`; coil's glyphs blur-fade at scale 0.8 with them and its check and × also draw in on `fade`, once per appearance; an app's icons animate themselves or fade and scale. The icon stays in place while the button's label cross-fades beside it, start-aligned, on the same `swap` track, and the action springs to the new label's width on `standard` (`CoilInputCopyTrack.size`). Tracks: `CoilInputCopyTrack.fill`, `.mark`, `.action`, `.weight`, `.swap`, `.size`, `.draw`; the swap and draw run in the shared `CoilCopyGlyph`, keyed there by `CoilCopyTrack.swap` and `.draw`. Reduced motion makes the swap instant; coil's check still draws in on `fade`.
- **Value font:** coil bundles no monospace font; the value is the theme's font with tabular figures and a slashed zero. Apps set `CoilInputCopyStyle.valueStyle` for a real mono.
- **Semantics:** a button named "Copy" plus the Field label (or `semanticLabel`); its value is the full text. It announces "Copied" or "Copy failed" when the result appears (not again for a copy that only extends it).
- **Keyboard:** Enter or Space copies.
