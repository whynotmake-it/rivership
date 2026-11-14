# Dropdown

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/context_menu.dart';
import 'package:coil/dropdown.dart';
```

Exports `CoilContextMenu`, `CoilDropdown`, `CoilDropdownStyle`, `CoilDropdownTriggerBuilder`.

To change its look or composition, eject a copy into your app with `dart run coil:eject dropdown` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Dropdown (action menu; +sub, +search)

- **Anatomy:** popup (§13.2) → rows (§13.1) with optional leading icon, label, trailing shortcut caps (pointer) or chevron (submenu); group labels (caption muted, padding 8 / 6); separators (1 px, edge to edge, 4 above and below, in `border` at 60 % of its own alpha: foreground at about 7 %); checkable rows (check or radio dot, trailing); destructive rows (`redLabel`, last, after a separator); empty state (muted, centered, padding 24).
- **Sizes:** rows per §13.1. Default width 288 (pointer), `max(trigger, 220)` (touch). Submenu width 224.
- **States:** the pointer highlight glides; checked rows are semibold with a check; the single-choice selected fill glides on `standard`; disabled rows are skipped.
- **Submenus:**
  - Pointer: open on hover after 100 ms with a safe triangle, or on Right / Enter. Placed 2 px from the parent, with the first row level with the trigger row. Left or Esc closes one level.
  - **Touch: tap to drill.** In a touch popover the submenu *replaces* the parent in place, with a "‹ Parent" back row; the panel height springs and the page slides on `standard`. In a sheet it's the same push.
- **Search** (`DropdownSearch`): a field band one row high at the top with a hairline below. Typing filters by word prefix, and printable keys typed into the list go to the field. Pointer: autofocused. Touch sheet: not autofocused.
- **Presentation:** §9.1. ≤ 8 items, no search and ≤ 1 submenu level stay anchored on phones.
- **Motion:** popup blur-fade on the tier's popover tokens (§7.2); highlight `quick`; sub push `standard`.
- **Keyboard:** arrows loop and skip disabled rows; Home and End; typeahead; Enter or Space activates; Esc closes one level; Tab closes all. Activating closes the menu after `acknowledgeDuration` for checkable rows (the whole menu, submenus included, ignores input meanwhile), and immediately for actions.
- **Semantics:** menu, menuItem / menuItemCheckbox / menuItemRadio, `expanded` on the trigger.
- **Haptic:** iOS `selectionClick` on a pick in a sheet.
- **Do:** keep it to ≤ 12 items and ≤ 1 submenu level.
- **Don't:** put form inputs inside menus; nest more than 2 levels.

## ContextMenu

- **The Dropdown, opened at a point.**
- **Triggers:** right-click; Ctrl-click (macOS); Shift+F10 / Menu key (at the focused element); **long-press 500 ms on touch**.
- **Touch:** the pressed element lifts (scale 1.02 and shadow +1 on `quick`) with a haptic (§8.6). The menu anchors at the touch point as a touch popover (≤ 8 items), else a sheet.
- **Don't:** use the iOS preview-blur; put the only path to an action in a context menu (also offer a visible ⋯ button).
