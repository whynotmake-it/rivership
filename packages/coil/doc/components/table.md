# Table

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/table.dart';
```

Exports `CoilSortDirection`, `CoilTable`, `CoilTableColumn`, `CoilTableLabels`, `CoilTableStyle`, `CoilTableTrack`.

To change its look or composition, eject a copy into your app with `dart run coil:eject table` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Table

- **Anatomy:** a header row (semibold, caption muted on pointer); body rows (cells muted, foreground when the row is lit or selected); hairline cell rules (`border`); an optional empty state that holds N rows of height.
- **Sizes:** cell padding `controlPaddingX` × vertical pad: rows 36 / 28 / 44 / 36.
- **States:** the row highlight glides (pointer); selected rows merge (§8.4); press fill on touch. A header cell that sorts is pressable.
- **Overflow:** scrolls horizontally inside a ScrollArea, with its edge fades where columns are hidden. A fade, not a shadow: it is the same signal every coil scroll region uses.
- **Pinned first column:** not built yet. It needs a two-dimensional viewport; the plan is `two_dimensional_scrollables`' `TableView` with `pinnedColumnCount: 1`, shared with the DataTable.
- **Motion:** highlight `quick`; selection `standard`.
- **Keyboard:** Tab to the table; arrows move the active row (and cell in interactive tables); Space selects; Enter opens.
- **Semantics:** table / row / cell roles with column headers.
- **Don't:** zebra stripes.
