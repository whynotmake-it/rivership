# Calendar

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/calendar.dart';
```

Exports `CoilCalendar`, `CoilCalendarLabels`, `CoilTimeColumns`.

To change its look or composition, eject a copy into your app with `dart run coil:eject calendar` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Calendar

- **Anatomy:**
  - caption: "‹ November 2026 ›" (title role) with the month/year label opening a jump grid;
  - weekday row (caption muted, locale first day);
  - a 6 × 7 day grid (body, tabular), **always 6 rows** so the height never jumps.
- **Cell sizes:** 36 / 32 / 44 / 40.
- **Day states:**
  - outside the month: muted 60 %;
  - today: semibold with a 4 `brand` dot;
  - selected: `foreground` fill with `background` text;
  - range: an `active` band per week row (merged-selection block, rounded at the ends) with the endpoints filled;
  - disabled: 40 % and struck through for "booked";
  - hover (pointer): the gliding highlight; in range picking, the highlight *is* the proposed end.
- **Months:** pointer and tablets show 2 side by side when they fit; phones show 1.
- **Motion:** month change slides the grid by ⅓ of the stride with a crossfade on `standard`; on touch, **horizontal paging follows the finger and keeps the fling velocity**; highlight `quick`; range band `standard`.
- **Keyboard:** arrows move the day; PageUp/PageDown change the month; Shift+PageUp/PageDown change the year; Home and End go to the week's start and end; Enter selects.
- **Semantics:** grid cells carry full-date labels; previous and next month are semantics actions.
