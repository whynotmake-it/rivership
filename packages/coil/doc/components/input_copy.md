# InputCopy

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/input_copy.dart';
```

Exports `CoilInputCopy`, `CoilInputCopyAlign`, `CoilInputCopyLabels`, `CoilInputCopyStyle`, `CoilInputCopyTrack`, `CoilInputCopyVariant`.

To change its look or composition, eject a copy into your app with `dart run coil:eject input_copy` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## InputCopy

- **Anatomy:** a read-only row (monospace value, truncated) plus a copy action: `icon` or `button` ("Copy"), on the trailing side or with `align: start`. Label it with a Field: a tap on the label copies.
- **Sizes:** row = `controlHeight`, padding `controlPaddingX`.
- **States:**
  - idle;
  - hover (pointer): the value gets a `brand` 20 % mark and the action turns foreground;
  - after a copy: `copied` (check) or `failed` (× in destructive) for 2 s, then idle.
  - The button label width is reserved by a "Copied" ghost.
- **Feedback:** **inline on every platform.** The icon swaps to a drawn check and the button label reads "Copied". On iOS and Android also `selectionClick`. A pointer tooltip ("Copy to clipboard") is optional extra, never the only feedback.
- **Motion:** icon swap: blur-fade at scale 0.8, in on `quick`, out on `quickExit`. The two overlap briefly. The check and × draw in on `fade`. Tracks: `CoilInputCopyTrack.fill`, `.mark`, `.action`, `.weight`, `.swap`, `.draw`.
- **Value font:** coil bundles no monospace font; the value is Inter with tabular figures and a slashed zero. Apps set `CoilInputCopyStyle.valueStyle` for a real mono.
- **Semantics:** a button named "Copy" plus the Field label (or `semanticLabel`); its value is the full text. It announces "Copied" or "Copy failed".
- **Keyboard:** Enter or Space copies.
