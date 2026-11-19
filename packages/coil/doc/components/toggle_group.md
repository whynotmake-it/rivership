# ToggleGroup

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/toggle_group.dart';
```

Exports `CoilToggleGroup`, `CoilToggleGroupStyle`, `CoilToggleGroupTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject toggle_group` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## ToggleGroup

- **Anatomy:** a horizontal segmented row: a 1 px `border` hairline with `segmentPadding` (4, compact 2) between it and the segments. Selected segments merge into one block.
- **Sizes:** segment height `controlHeight`, padding `controlPaddingX`; the row is `segmentPadding` taller on each side.
- **Shape:** segments, blocks and the highlight at the item radius; the row concentric with them, `segmentPadding` out (`CoilRadii.concentric`: 12 pointer, 10 compact, 14 touch).
- **Motion:** merge/split `standard`, highlight `quick`.
- **Keyboard:** roving; Left and Right move; Space toggles.
- **Semantics:** toggle buttons with `selected`.
- **Use:** multi-select formatting (Bold / Italic). For single choice use Tabs or a RadioGroup.
