# Select / MultiSelect

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/combobox.dart';
import 'package:coil/date_picker.dart';
import 'package:coil/select.dart';
```

Exports `CoilCombobox`, `CoilDatePicker`, `CoilMultiCombobox`, `CoilMultiSelect`, `CoilSelect`, `CoilSelectStyle`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject select` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

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
- **Sizing:** the popover hugs the calendar's seven cells; a sheet's calendar fills the sheet's width up to days 20 % past their natural side and centers past it (Calendar § Width); the time columns are as wide as the calendar above them. Both scroll when the window is too short. On the touch tier, in a short, wide window (wider than tall and under 600 tall: a phone in landscape) the time columns sit beside the calendar instead of under it. A short desktop window keeps them under it and scrolls.
- **Pointer / tablet:** a popover with Calendar; presets in a 152 column on the leading side (below when narrow); time fields as compact Combobox inputs (typed, 15-minute list).
- **Phone (touch, < 600): a sheet built for the thumb.**
  - Caption row (title role; the ▾ opens the month/year grid) → one month, 44 cells, **horizontal paging**, fixed 6 rows.
  - Presets: a horizontally scrolling chip row (Today, Tomorrow, Next week…).
  - Time: chips ("Start 11:00", "End 12:45"). Tapping one pushes the **time page** inside the sheet on `standard`, with a "‹ Date" back row.
    - The time page is **two snap columns** (hours | minutes in the minute step), flat rows: a line of body text in tabular figures and the tier's gap (28 pointer, 34 touch at 1×, grown with the text scale), **five visible**. The rows fade out toward the top and bottom over two rows (the scroll edge fade). A selection band in `active` with the day cells' radius sits across the center; the center row and the colon are foreground semibold and the others are muted. The columns are a day and a half wide each.
    - The columns snap on `standard` with the fling velocity. No 3D wheel.
    - A duration caption ("1 h 45 min") sits under the end column. "Type a time" opens a numeric field (opt-in).
  - Footer: a summary footer (§13.5) pinned as the sheet's footer (`CoilSheetPanel.footer`, 16 from the sides): the draft on the leading side, **Done** (primary, `CoilCalendarLabels.confirm`) at its own width on the trailing side. Clear (ghost) joins Done in range mode, before it.
- **Footer summary (built):** wherever the picker has a footer with Done (every sheet; a popover that picks a time), its leading side names the **draft** Done will confirm, not the last confirmed value, so the selection stays readable however far the calendar has paged or zoomed, and follows every pick and every turn of a time column. `CoilCalendarLabels.summary` shows it, `summaryLabel` names it for screen readers:
  - date: "Fri, Nov 22, 2019" ("Selected: Friday, November 22, 2019");
  - with time: "Fri, Nov 22, 2019, 14:30";
  - range (when range mode lands): "Nov 13 – 15, 2026", "Nov 28 – Dec 3, 2026" across months, "Dec 29, 2026 – Jan 2, 2027" across years;
  - nothing picked: the picker's `placeholder` ("Pick a date"), muted, beside the disabled Done.
  - A date-only popover gets **no** footer for it: a tap there commits and closes, and the field under it shows the value. Nothing is added to the popover just to show the selection.
- **Confirming (built):** what's picked in the open calendar is a draft; only a confirm reports it (`onChanged`), and every other way out cancels.
  - **Sheet (date, or date and time): Done confirms.** The close button, the scrim, a drag down, back and Escape cancel; reopening starts from the value. A sheet is a modal task that takes the screen, the platform pickers presented that way confirm explicitly (Material's modal date picker dialog and bottom sheet: Cancel + OK), and the sheet already has its close button as the Cancel, so the footer holds the one primary action.
  - **Popover, date only: a tap on a day confirms and closes**, as iOS's compact `UIDatePicker` popover, shadcn/Radix and React Aria (`shouldCloseOnSelect`, default true), MUI's desktop picker (no action bar on desktop) and Fluid Functionalism (`onValueChange` on a pick) do. One tap is the whole answer, so a button would only add a step.
  - **Popover with time: Done (trailing, at its own width, after the draft's summary) confirms**, as MUI's desktop date-time picker's accept action does: a date and a time are two answers, and no single tap marks the end. A tap outside or Escape cancels.
  - Done is disabled until something is picked. Enter anywhere in the popup confirms (on the grid it picks the focused day first); Space only picks; Escape cancels (in the month view it returns to the days first).
- **Keyboard:** as Calendar, plus Enter to confirm and Escape to cancel. Esc restores the previous range. Hardware keyboards on iPad get the typed time field.
- **Semantics:** the snap columns are adjustable (VoiceOver swipe up/down changes the hour).
- **Scope:** v1 includes date, range, presets and time. The time page can land one milestone after the grid. A drag-to-select range is later.
