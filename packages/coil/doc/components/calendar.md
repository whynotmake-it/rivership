# Calendar

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/calendar.dart';
```

Exports `CoilCalendar`, `CoilCalendarLabels`, `CoilTimeColumns`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject calendar` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Calendar

- **Anatomy:**
  - caption: "‹ November 2026 ›" (title role) with the month/year label opening a jump grid;
  - weekday row (caption muted, locale first day);
  - a 6 × 7 day grid (body, tabular), **always 6 rows** so the height never jumps.
- **Cell sizes:** square, the control height (36 / 28 / 44 / 36), grown by as much as the text scale grows the line box (the padding doesn't scale).
- **Width:** seven cells when it can choose (a popover hugs it); a wider space it's given is filled (a phone sheet), with the cell's fill a square in the middle of each column; a narrower one is shared, the rows shrink to stay square (measured inside the focus ring's inset, so the columns and rows match) and the numbers scale down rather than wrap.
- **Day states:**
  - outside the month: muted 60 %;
  - today: semibold with a 4 `brand` dot;
  - selected: `foreground` fill with `background` text;
  - range: an `active` band per week row (merged-selection block, rounded at the ends) with the endpoints filled;
  - disabled: 40 % and struck through for "booked";
  - hover (pointer): the gliding highlight; in range picking, the highlight *is* the proposed end.
- **Months:** pointer and tablets show 2 side by side when they fit; phones show 1.
- **Motion:** the months are pages: the arrows and PageUp/PageDown slide a full page on `standard`, and a jump of more than one month (Shift+PageUp) is a cut. On touch, **horizontal paging follows the finger and keeps the fling velocity**: a swipe past half a page or a flick turns one page, anything less springs back, all on `standard`. A trackpad's horizontal swipe pages too; a mouse drag doesn't. Highlight `quick`; range band `standard`.
- **Haptics:** `toggle` when a swipe lands on a new month and as a time column passes a row; `pick` when a finger picks a day (not on a click, Enter or Space, as in the select's list).
- **Keyboard:** arrows move the day; PageUp/PageDown change the month; Shift+PageUp/PageDown change the year; Home and End go to the week's start and end; Enter selects.
- **Semantics:** grid cells carry full-date labels; previous and next month are semantics actions.
