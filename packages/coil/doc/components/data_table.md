# DataTable

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/data_table.dart';
```

Exports `CoilDataColumn`, `CoilDataTable`, `CoilDataTableController`, `CoilDataTableLabels`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject data_table` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## DataTable

- **v1 scope:**
  - a headless controller (sort, search, column filters, visibility, pagination, selection);
  - the grid (Table look, rows 36 / 28 / 44 / 36);
  - a select column (checkboxes always visible);
  - a sortable header menu (Sort ascending/descending, Clear, Hide);
  - row actions (a trailing ⋯ ghost button, 28 / 44 hit) and the same items as a context menu;
  - search (a ghost icon button that springs open to a 224 field on `standard`);
  - pagination (compact buttons, 44 hit on touch);
  - the full row keyboard model;
  - skeleton and empty states;
  - a pinned first column.
- **Deferred (v2):** typed filter chips, inline editors, column reorder and resize, sub-rows, the selection command bar, layout FLIP.
- **States:** the row highlight glides (pointer); selection merges (§8.4); press fill (touch).
- **Touch:**
  - rows 44, cell padding 16, the sticky first column with an edge shadow once scrolled;
  - no resize or move handles;
  - header menus anchored;
  - row actions on long-press plus the visible ⋯;
  - an optional `mobileLayout: cards` below 600 (label : value pairs);
  - selection shows a bottom action bar above the safe area.
- **Keyboard:** arrows move the active row; Space selects; Shift+arrows extend; Enter opens; ⌘A / Ctrl+A selects all; Esc clears the selection; Shift+F10 opens row actions.
- **Semantics:** table roles, the header with sort state, rows `selected`.
- **Title:** display role, aligned past the select column.
