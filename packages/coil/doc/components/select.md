# Select / MultiSelect

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/combobox.dart';
import 'package:coil/date_picker.dart';
import 'package:coil/select.dart';
```

Exports `CoilCombobox`, `CoilDatePicker`, `CoilMultiCombobox`, `CoilMultiSelect`, `CoilSelect`, `CoilSelectStyle`.

To change its look or composition, eject a copy into your app with `dart run coil:eject select` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Select / MultiSelect

- **Trigger:** like Input (hairline, `controlHeight`, `controlPaddingX`, min width 160) → [icon] value (placeholder muted) → chevron (muted → foreground on hover). Hover is the `hover` fill. While open it holds the `active` fill.
- **List:** popup rows; a trailing check; selected `active` fill in popovers; check only in sheets; multi-select uses merged blocks plus checks.
- **Presentation:** pointer popover (max height 300); phone ≤ 8 options touch popover; > 8 options or multi → sheet with the field label as its title. Lists over 12 options add a search row.
- **Motion:** the check draws on `fade`; a pick holds `acknowledgeDuration` (300 ms), ignoring input, then closes; the selected fill glides `standard`.
- **Keyboard:** the trigger opens on Enter, Space, Up or Down (the list starts on the picked row with the ring). The list has arrows, Home/End, PageUp/PageDown, typeahead, Enter/Space to pick, and Esc/Tab to dismiss. Focus returns to the trigger.
- **Semantics:** the trigger is a button with `expanded` and its value; the list is a menu; rows are `selected`.
- **Don't:** use it for fewer than 3 options (use a RadioGroup or Tabs) or for actions (use Dropdown).

## Combobox

- **Anatomy:** an input (field role) with an optional clear button and chevron; a list below (§13.2) with match highlighting (semibold on the matched prefix); an optional "Create '…'" row last; an empty state.
- **Multi:** chips wrap inside the field before the input. A chip is 24 / 20 / 28 / 24 high, padding 8, caption, `hover` fill, item radius (pill → full). Its remove × is 16 visual with the hit box growing to the chip height (44 on touch). The field height springs on `quick` as chips wrap.
- **Pointer:** the list anchors under the input, at least the input's width, max height 300; the input keeps focus.
- **Phone:** a **full-height sheet**. The input is on top, focused, with the keyboard up. Chips sit above the input, results below, and Done in the header for multi.
- **Motion:** chips enter scale 0.9 → 1 + fade on `quick` (growing from the leading edge) and exit on `quickExit`; siblings slide on `standard`; the list blur-fades on the tier's popover tokens (§7.2).
- **Keyboard:** typing filters and the active item resets to the first match; Up and Down move the active item; Enter picks it (IME-safe); Esc clears, then closes; Backspace on an empty input removes the last chip; Left and Right move between chips.
- **Semantics:** a combobox textField with `expanded`; rows `selected`; a live result count; the chip toolbar is labeled "Selected".
- **Do:** use it for long or open-ended option sets.
- **Don't:** autocomplete inline over the user's typing.

## DatePicker

- **Trigger:** like a Select trigger: [calendar icon] label ("Wed Nov 13", "Nov 13 – 15", placeholder muted), plus an optional clear ×. Width is stable: reserved for the widest label in the locale.
- **Pointer / tablet:** a popover with Calendar; presets in a 152 column on the leading side (below when narrow); time fields as compact Combobox inputs (typed, 15-minute list).
- **Phone (touch, < 600): a sheet built for the thumb.**
  - Grabber → caption row (title role; the ▾ opens the month/year grid) → one month, 44 cells, **horizontal paging**, fixed 6 rows.
  - Presets: a horizontally scrolling chip row (Today, Tomorrow, Next week…).
  - Time: chips ("Start 11:00", "End 12:45"). Tapping one pushes the **time page** inside the sheet on `standard`, with a "‹ Date" back row.
    - The time page is **two snap columns** (hours | minutes in the minute step), flat 44 rows. A selection band in `active` sits across the center, the center row is foreground semibold and the others are muted.
    - The columns snap on `standard` with the fling velocity. No 3D wheel.
    - A duration caption ("1 h 45 min") sits under the end column. "Type a time" opens a numeric field (opt-in).
  - Footer: Clear (ghost) and **Done** (primary) in range and time modes. A single date commits on tap and closes after 200 ms.
- **Keyboard:** as Calendar. Esc restores the previous range. Hardware keyboards on iPad get the typed time field.
- **Semantics:** the snap columns are adjustable (VoiceOver swipe up/down changes the hour).
- **Scope:** v1 includes date, range, presets and time. The time page can land one milestone after the grid. A drag-to-select range is later.
