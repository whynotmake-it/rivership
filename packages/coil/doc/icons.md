# Icons

coil bundles no icon set and depends on no icon package. It draws a few
glyphs itself (a tick, a dash, chevrons, an ×), and an app can swap every one
of them for its own icon set in one place: `CoilThemeData.icons`. This page
shows how, with complete sets for Lucide and Material Symbols, and how an
icon can bring its own animation.

The design is in DESIGN.md §11 and the API rules in
[api_guide.md](api_guide.md) §5.

## The role map

`CoilIcons` has one `Widget?` field per role, named for what the icon means,
not for its shape. Null keeps coil's drawn glyph, so a partial set replaces
only the roles it names.

| Role | Where coil shows it |
|---|---|
| `check` | checkbox tick, select and combobox checkmark, menu check, question rows' check, the copy feedback after a copy |
| `dash` | an indeterminate checkbox |
| `copy` | the copy action at rest (`CoilInputCopy`, `CoilCopyGlyph`) |
| `failed` | the copy feedback after a refused copy |
| `close` | sheet and dialog close buttons, banner and card dismiss, queued card remove, combobox chip and attachment remove |
| `alert` | a field's error |
| `chevronStart` | calendar's previous month or year, data table's previous page, a menu's back row |
| `chevronEnd` | calendar's next month or year, data table's next page, breadcrumb separator, accordion, thinking steps and sidebar disclosures (turned a quarter when open), a menu's submenu row, the arrow a question row's key turns into |
| `chevronDown` | select and combobox indicator, calendar's month title, the queued stack's collapse button, table sorted descending |
| `chevronUp` | table sorted ascending |
| `send` | the composer's send button |
| `stop` | the composer's stop button |

The order of precedence is:

1. a widget passed to the component's own slot (`CoilSelect.checkmark`,
   `CoilBanner.dismissIcon`, `CoilBreadcrumb.separator`, …);
2. the theme's `CoilIcons` entry;
3. coil's drawn glyph.

```dart
CoilTheme(
  data: CoilThemeData(
    icons: const CoilIcons(
      check: Icon(LucideIcons.check),
      close: Icon(LucideIcons.x),
    ),
  ),
  child: app,
)
```

Add a partial set to an existing theme with `merge`, which keeps the roles it
doesn't name:

```dart
theme.copyWith(icons: theme.icons.merge(const CoilIcons(close: Icon(LucideIcons.x))))
```

`CoilIcons.copyWith(check: null)` puts one role back to coil's glyph.

### Styling

Icons are plain widgets, styled like any slot by the ambient `IconTheme`:
`size` (the tier's icon size), `color` (the label's current color),
`weight` and `applyTextScaling: true`. Flutter's `Icon` reads all of them.
coil raises `weight` from 400 (`CoilIconWeight.rest`, a 1.5 stroke) to 533
(`CoilIconWeight.emphasis`, a 2 stroke) on hover and for indicators (a
checkbox tick, a select check, a field's alert, the sheet's close ×). A
variable icon font follows that by itself; a set that ships one static font
per stroke can pick a font by weight (see Lucide below); a filled set simply
loses the cue.

A painted icon should size itself with `CoilIconSize.of(context)`, which
applies the text scale like `Icon` does. coil lays icons out like `Icon`:
an icon sits exactly where coil's glyph sat, at the same size and centered
the same way, on both tiers and at any text scale.

### Right to left

coil's drawn `chevronStart` and `chevronEnd` point the other way in RTL. A
custom icon handles direction itself: use an icon that mirrors with the text
(`IconData(…, matchTextDirection: true)`, which both sets below use for their
chevrons), or pick by `Directionality.of(context)`. coil turns a disclosure's
`chevronEnd` a quarter toward the end when it opens, so it points down in
both directions as long as the icon points to the end.

## Lucide

For [`lucide_icons_flutter`](https://pub.dev/packages/lucide_icons_flutter)
4.0.3 (Lucide 1.70), the maintained Lucide package on pub.dev. Lucide ships
one static font per stroke (weights 100 to 600 are strokes 0.5 to 3), so a
small widget picks coil's two strokes: 1.5 at rest (`LucideIcons300`) and 2
at emphasis (`LucideIcons400`, Lucide's default).

```dart
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

const lucideIcons = CoilIcons(
  check: LucideIcon(LucideIcons300.check, LucideIcons400.check),
  dash: LucideIcon(LucideIcons300.minus, LucideIcons400.minus),
  copy: LucideIcon(LucideIcons300.copy, LucideIcons400.copy),
  failed: LucideIcon(LucideIcons300.x, LucideIcons400.x),
  close: LucideIcon(LucideIcons300.x, LucideIcons400.x),
  alert: LucideIcon(LucideIcons300.circleAlert, LucideIcons400.circleAlert),
  // The Dir variants mirror in RTL, as coil's chevrons do.
  chevronStart: LucideIcon(
    LucideIcons300.chevronLeftDir,
    LucideIcons400.chevronLeftDir,
  ),
  chevronEnd: LucideIcon(
    LucideIcons300.chevronRightDir,
    LucideIcons400.chevronRightDir,
  ),
  chevronDown: LucideIcon(LucideIcons300.chevronDown, LucideIcons400.chevronDown),
  chevronUp: LucideIcon(LucideIcons300.chevronUp, LucideIcons400.chevronUp),
  send: LucideIcon(LucideIcons300.arrowUp, LucideIcons400.arrowUp),
  stop: LucideIcon(LucideIcons300.square, LucideIcons400.square),
);

/// A Lucide icon at coil's two strokes: 1.5 at rest, 2 where coil raises
/// the weight to emphasis.
class LucideIcon extends StatelessWidget {
  const LucideIcon(this.rest, this.emphasis, {super.key});

  final IconData rest;
  final IconData emphasis;

  @override
  Widget build(BuildContext context) {
    final weight = IconTheme.of(context).weight ?? CoilIconWeight.rest;
    return Icon(weight > CoilIconWeight.rest ? emphasis : rest);
  }
}
```

With only `package:lucide_icons_flutter/lucide_icons.dart`, use
`Icon(LucideIcons.check)` and so on: one stroke (2) everywhere.

## Material Symbols

For [`material_symbols_icons`](https://pub.dev/packages/material_symbols_icons)
4.2960.0. Its fonts are variable, so `Icon` follows coil's `weight` (400 at
rest, 533 at emphasis) with no extra code. Only variable fonts honor
`IconTheme.weight`: a static icon font, or a filled set, draws one weight
whatever coil asks for, the same caveat as Fluid Functionalism's filled sets.

```dart
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

const materialSymbolsIcons = CoilIcons(
  check: Icon(Symbols.check),
  dash: Icon(Symbols.remove),
  copy: Icon(Symbols.content_copy),
  failed: Icon(Symbols.close),
  close: Icon(Symbols.close),
  alert: Icon(Symbols.error),
  // chevron_left and chevron_right mirror in RTL.
  chevronStart: Icon(Symbols.chevron_left),
  chevronEnd: Icon(Symbols.chevron_right),
  chevronDown: Icon(Symbols.keyboard_arrow_down),
  chevronUp: Icon(Symbols.keyboard_arrow_up),
  send: Icon(Symbols.arrow_upward),
  stop: Icon(Symbols.stop),
);
```

Use `Symbols.check_rounded` and the like for the rounded style.

## Animated icons

Where coil animates an icon (it appears, disappears or swaps with another),
it wraps the icon in a `CoilIconPresence` carrying an `Animation<double>`:
0 when the icon is absent, 1 when it is fully there. These are the
checkbox's tick and dash, the select's and question rows' check, the copy
feedback (copy, check, ×) and the composer's send and stop.

- An icon that reads `CoilIconPresence.maybeOf(context)` animates itself
  from it, and coil leaves it alone.
- An icon that doesn't read it fades in and out and grows from 80 % with
  the same presence (`CoilIconPresence.absentScale`). Every icon above does
  this out of the box.
- Outside an animation, `maybeOf` returns null: draw the icon complete.

The presence runs on coil's motion tokens (the checkbox's tick on `fade`
and `fadeExit`, the copy and send swaps on `quick` and `quickExit`), is
clamped to 0 to 1 (a bounce belongs outside the icon), and under reduced
motion jumps to its end. A swap is two presences crossing: the outgoing
icon's goes from 1 to 0 while the incoming icon's goes from 0 to 1. The
`Animation` object stays the same while it runs, so listen to it (a
painter's `repaint`, an `AnimatedBuilder`) instead of rebuilding.

### A check that draws itself

coil's own tick works this way:

```dart
class DrawnCheck extends StatelessWidget {
  const DrawnCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(CoilIconSize.of(context)),
      painter: _CheckPainter(
        // Null outside an animation: draw the whole check.
        CoilIconPresence.maybeOf(context),
        icon.color!,
        // coil's stroke: 1.5 at rest, 2 at emphasis.
        1.5 * icon.weight! / CoilIconWeight.rest,
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  // Repaints with the presence, without a rebuild per frame.
  _CheckPainter(this.presence, this.color, this.stroke)
    : super(repaint: presence);

  final Animation<double>? presence;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = presence?.value ?? 1;
    if (drawn == 0) return;
    final check = Path()
      ..moveTo(5, 12)
      ..lineTo(10, 17)
      ..lineTo(19, 7);
    final part = Path();
    for (final metric in check.computeMetrics()) {
      part.addPath(metric.extractPath(0, metric.length * drawn), Offset.zero);
    }
    canvas
      ..scale(size.width / 24)
      ..drawPath(
        part,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.presence != presence || old.color != color || old.stroke != stroke;
}

// The rest of the set stays as it is.
theme.copyWith(icons: theme.icons.merge(const CoilIcons(check: DrawnCheck())));
```

### Lottie

A Lottie animation plays with the presence as its controller, and shows its
last frame outside an animation:

```dart
check: Builder(
  builder: (context) => Lottie.asset(
    'assets/check.json',
    width: CoilIconSize.of(context),
    height: CoilIconSize.of(context),
    controller: CoilIconPresence.maybeOf(context) ?? kAlwaysCompleteAnimation,
  ),
),
```

### In your own components

`CoilIcon(.check)` shows the theme's icon for a role or coil's glyph, and
`CoilIconSwitcher` shows an icon in a presence and crosses two on a swap:

```dart
CoilIconSwitcher(
  motion: CoilTheme.motionOf(context).fade,
  exitMotion: CoilTheme.motionOf(context).fadeExit,
  child: done ? const CoilIcon(.check) : null,
)
```

## Not covered

- **Morphs.** There is no contract for one shape turning into another (a
  copy icon folding into a check); a swap is two icons crossing. A morph
  could later be a third kind of icon that receives both roles.
- **Progress.** The presence is how far an icon is in or out, not a linear
  timeline: it follows a spring and can't be scrubbed at a constant rate. A
  linear-progress flag for timeline animations is a possible follow-up.
- **The loading spinner** isn't a role. It loops rather than appearing, and
  a static icon wouldn't turn; replace it per button with
  `CoilButton.loadingIndicator`, which shows its widget as it is.
