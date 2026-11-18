# Calendar

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/calendar.dart';
```

Exports `CoilCalendar`, `CoilCalendarLabels`, `CoilCalendarWidth`, `CoilTimeColumns`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject calendar` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Calendar

- **Anatomy:**
  - caption: the month title, a button "November 2026 ⌄" (body, semibold, a ghost-style fill on hover and press, the focus ring) at the start, and the ‹ › arrows at the end. The title zooms out to the month view (below);
  - weekday row (caption muted, locale first day);
  - a 6 × 7 day grid (body, tabular), **always 6 rows** so the height never jumps.
- **Cell sizes:** square, the control height (36 / 28 / 44 / 36), grown by as much as the text scale grows the line box (the padding doesn't scale).
- **Width:** seven cells when it can choose (a popover hugs it). A wider space it's given is filled until the days are 20 % past their natural side (a phone sheet); past that the calendar centers at that width (a tablet sheet), so **days are always square** and never stretch into wide rectangles. The cell's fill is the natural-size square in the middle of each cell. A narrower space is shared: the rows shrink to stay square (measured inside the focus ring's inset, so the columns and rows match) and the numbers scale down rather than wrap.
- **Hit area:** each day takes the tap on its whole cell, with no gaps between days or rows; a tap in the focus ring's inset at either edge of the grid picks the edge day.
- **Day states:**
  - outside the month: muted 60 %;
  - today: semibold with a 4 `brand` dot;
  - selected: `foreground` fill with `background` text;
  - range: an `active` band per week row (merged-selection block, rounded at the ends) with the endpoints filled;
  - disabled: 40 % and struck through for "booked";
  - hover (pointer): the gliding highlight; in range picking, the highlight *is* the proposed end.
- **Months:** pointer and tablets show 2 side by side when they fit; phones show 1.
- **Title follows the pages:** the title names the page more than half in view, so it changes mid-swipe while the finger is still down (and back, if the swipe returns), not when the page settles. The old and new names swap with the blur-fade (`MotionSizeSwitcher` with `CoilBlurFade` on `fade` / `fadeExit`, the width springing on `standard`). Large text in a narrow calendar scales the title down rather than cut off the year. It's announced (live region) as "November 2026".
- **Month view:** tapping the title (or Enter/Space on it) zooms out to the months: each year's twelve months, 3 × 4, under a muted caption-semibold year heading, in a vertical list that scrolls through the years. It fills exactly the weekday row and grid's space (rows as tall as a week's), so the calendar's height doesn't change. It opens with the shown month's year in the middle, the previous and next years fading in at the edges (the scroll-edge fade). The picked day's month is filled like a selected day; this month is semibold. Months outside `firstDate`/`lastDate` are dimmed and take no tap, and the list starts and ends at their years. Picking a month zooms back into its days. The arrows fade out while it shows, and the chevron turns up.
  - **Zoom:** spatial, from the title's corner: the days shrink to 90 % and fade while the months settle from 110 % to 100 % and fade in; back runs it in reverse. The scale springs on `standard` / `standardExit` (none under reduced motion, which keeps the fade on `fade` / `fadeExit`). The hidden view takes no pointer, focus or semantics; focus moves with the view when it was in the calendar.
  - **Keyboard:** one focus stop; arrows move a month (Up/Down a row of three), PageUp/PageDown a year, Enter or Space picks, Escape returns to the days (it doesn't close a popup). Arrows mirror in RTL.
  - In a sheet, the list uses `CoilSheetRoute.scrollBehaviorOf` like the pager, so a drag at its top hands off to the sheet.
- **Motion:** the months are pages: the arrows and PageUp/PageDown slide a full page on `standard`, and a jump of more than one month (Shift+PageUp) is a cut. On touch, **horizontal paging follows the finger and keeps the fling velocity**: a swipe past half a page or a flick turns one page, anything less springs back, all on `standard`. A trackpad's horizontal swipe pages too; a mouse drag doesn't. Highlight `quick`; range band `standard`.
- **Haptics:** `toggle` when a swipe lands on a new month and as a time column passes a row; `pick` when a finger picks a day (not on a click, Enter or Space, as in the select's list).
- **Keyboard:** Tab reaches the title, the arrows, then the grid. Arrows move the day; PageUp/PageDown change the month; Shift+PageUp/PageDown change the year; Home and End go to the week's start and end; Enter selects and submits (`onSubmitted`, which a date picker confirms with); Space only selects.
- **Semantics:** grid cells carry full-date labels; previous and next month are semantics actions; the title is a button named by `monthLabel`, with the `chooseMonthLabel` hint and an expanded state; month cells carry "Month Year" labels and selected/enabled states.
