# CommandMenu

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/command_menu.dart';
```

Exports `CoilCommandMenu`, `showCoilCommandMenu`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject command_menu` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## CommandMenu

- **Anatomy:** a search field (subtitle role, 48 high pointer, 52 touch); groups with caption headings; rows (§13.1) with icon, label and trailing shortcut caps; an empty state; a footer with key hints (pointer).
- **Pointer:** a dialog (size `lg`) placed at the top, `max(12 % of height, 50 % − 220)`, max height `min(440, 76 %)`. Opened with ⌘K / Ctrl+K through `Shortcuts`.
- **Touch phone:** a **full-height sheet**. The field is focused (the keyboard is the point). No shortcut caps, no footer. The soft keyboard's Search key runs the active row. The app must provide a visible entry point, since there's no shortcut.
- **iPad with keyboard:** the dialog, with ⌘ caps.
- **Filtering:** per-word prefix/substring matching (not fuzzy); groups with no hits hide.
- **Motion:** the panel height springs to the result height on `standard`; the highlight on `quick`; keyboard moves scroll the row to the center on `quick`.
- **Keyboard:** Up and Down wrap and skip disabled rows; Enter runs; Esc clears, then closes.
- **Semantics:** a combobox with a live result count.
