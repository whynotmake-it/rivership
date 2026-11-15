# CheckboxGroup

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/checkbox_group.dart';
```

Exports `CoilCheckboxGroup`, `CoilCheckboxGroupStyle`, `CoilCheckboxGroupTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject checkbox_group` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## CheckboxGroup

- **Anatomy:** a column of rows: [checkbox] label. Labels wrap and grow the row.
- **Sizes:** row = §13.1. The checkbox shrink-wraps inside the row.
- **States:**
  - checked rows merge into one `active` block (§8.4);
  - the pointer highlight glides on top;
  - the label is foreground (it rests muted on pointer when unchecked).
- **Motion:** merge/split on `standard`, highlight `quick`, tick `fade`, ring `quick`.
- **Keyboard:** each row is a tab stop. Up and Down move with wrapping; Home and End jump; Space or Enter toggles.
- **Semantics:** a group with a label; rows are `checked`.
- **Touch:** press fill only. Selection is the merged blocks.
- **Do:** use it for 2–10 related options.
- **Don't:** use it for mutually exclusive options.
