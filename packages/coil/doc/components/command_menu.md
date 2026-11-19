# CommandMenu

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/command_menu.dart';
```

Exports `CoilCommandMenu`, `CoilCommandMenuFooter`, `CoilCommandMenuHint`, `showCoilCommandMenu`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject command_menu` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## CommandMenu

- **Anatomy:** a search field (subtitle role, a line 48 high on pointer, 52 on touch, `CoilCommandMenu.searchHeightOf`) over a hairline; groups with caption headings; rows (§13.1) with icon, label and trailing shortcut caps; an empty state; in the dialog, a footer with key hints.
- **Footer** (`CoilCommandMenuFooter`, the `footer:` slot; null for none): a hairline (`border` at 60 %, like the menu's separators), then one line `controlHeight` high (36 pointer, 44 touch) whose text starts on the rows' text edge (`popupInset + itemPaddingX`). Each hint is a caption in `mutedForeground` followed by its key caps (Kbd), `buttonGap` apart (6 / 8); hints sit `gap × 2` apart (16 pointer, 24 touch) on one line, and hints that don't fit are cut at the end. The defaults (`CoilCommandMenuFooter.defaultHints`) are Select ↑ ↓, Run ↵ and Close esc; pass `hints:` to localize or replace them. Screen readers skip it. A phone's sheet has none.
- **Pointer:** a centered dialog panel, `min(560, window − 32)` wide, a fifth of the way down the window (top at 20 % of its height), at most `min(440, 76 %)` tall with the search line and footer (`CoilCommandMenu.maxHeight`, `maxHeightFraction`); the list scrolls inside. Opened with ⌘K / Ctrl+K through `Shortcuts`.
- **Touch phone:** a **full-height sheet**. The field is focused (the keyboard is the point). No shortcut caps, no footer. The soft keyboard's Search key runs the active row. The app must provide a visible entry point, since there's no shortcut.
- **iPad with keyboard:** the dialog, with ⌘ caps and the footer.
- **Filtering:** per-word prefix/substring matching (not fuzzy); groups with no hits hide.
- **Motion:** the panel height springs to the result height on `standard`; the highlight on `quick`; keyboard moves scroll the row to the center on `quick`.
- **Keyboard:** Up and Down wrap and skip disabled rows; Enter runs; Esc clears, then closes.
- **Semantics:** a combobox with a live result count.
