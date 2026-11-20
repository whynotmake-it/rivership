# coil

A Flutter design system built on [Motor](https://pub.dev/packages/motor)
springs. It works under any `WidgetsApp`, with no Material or Cupertino app
shell, and adapts to pointer and touch, keyboard and screen readers on every
platform.

- Dozens of components, from buttons and fields to sidebars, calendars and chat
  composers.
- Every transition is a spring, so interrupting one keeps its velocity.
- One look on every platform, with each platform's own conventions for
  menus, scrolling, text selection, haptics and back gestures.
- Themed with colors, shape, type, motion and icons, and each component can be
  copied into your app to edit it.

> Pre-release: coil's API may change before 1.0. It needs Flutter 3.47 or
> later.

## Install

```sh
flutter pub add coil
```

## Usage

```dart
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(
  WidgetsApp(
    color: const Color(0xFF6B97FF),
    builder: (context, _) => CoilTheme(
      data: CoilThemeData.light,
      child: Center(
        child: CoilButton(
          onPressed: () {},
          child: const Text('Save'),
        ),
      ),
    ),
  ),
);
```

`CoilTheme` is optional: without it components follow the platform
brightness. Visible text and icons are `Widget` slots (`child`, `leading`,
`label`), so pass `Text`, not a `String`.

`package:coil/coil.dart` exports everything. To depend on less, import
`package:coil/foundation.dart`, `package:coil/primitives.dart` or a single
component's library such as `package:coil/button.dart`.

## Components

| | |
|---|---|
| Controls | `CoilButton`, `CoilBadge`, `CoilKbd`, `CoilCheckbox`, `CoilSwitch`, `CoilSlider`, `CoilRangeSlider`, `CoilInput` (and `.multiline`), `CoilInputGroup`, `CoilInputCopy`, `CoilSkeleton` |
| Forms | `CoilField` (with `CoilFieldSet`, `CoilFieldGroup`, `CoilFieldSeparator`), `CoilCheckboxGroup`, `CoilRadioGroup`, `CoilToggleGroup`, `CoilTabs`, `CoilSelect`, `CoilMultiSelect`, `CoilCombobox`, `CoilCalendar`, `CoilDatePicker` |
| Menus and overlays | `CoilDialog`, `CoilSettingsDialog`, `CoilTooltip`, `CoilDropdown`, `CoilContextMenu`, `CoilCommandMenu` |
| Layout and display | `CoilAccordion`, `CoilCard`, `CoilTable`, `CoilDataTable`, `CoilBanner`, `CoilBreadcrumb`, `CoilScrollArea`, `CoilCarouselDots`, `CoilFileThumbnail`, `CoilReveal`, `CoilSidebarScaffold` (with `CoilSidebar`) |
| Chat | `CoilChatMessage`, `CoilInputMessage`, `CoilQueuedStack`, `CoilThinkingSteps`, `CoilThinkingIndicator`, `CoilAskUserQuestions` |

The pieces they are built from, such as `CoilInteraction`, `CoilFocusRing`,
`CoilPopover`, `CoilSheetRoute` and `CoilTextFieldCore`, are public in
`primitives.dart` for building your own. The catalog in [`example/`](example)
shows every component live.

## Theming

Change things in the theme before reaching for anything else:

```dart
CoilTheme(
  data: CoilThemeData(
    shape: CoilShape.pill,
    typography: CoilTypography.inter(),
  ),
  child: app,
)
```

- `CoilColors.fromSeed(brightness:, brand:)` builds the colors.
- `CoilShape` is `.rounded`, `.pill` or `.sharp`. Every rounded corner is a
  superellipse.
- `CoilMotion` holds the springs, which you can change app-wide, per subtree
  with `CoilTheme.override`, or per component.
- `CoilTier` picks pointer or touch sizes. By default it follows the platform.
- `withComponentStyle(CoilButtonStyle(...))` restyles one component type.

[`DESIGN.md`](DESIGN.md) describes coil's design language: color, type,
spacing, shape, motion, interaction and each component's anatomy.

## Fonts

coil bundles no font, so apps don't carry one they don't use. By default it
uses the platform's UI font. Two presets are tuned for specific fonts:

- `CoilTypography.allo()`, for [Allo](https://allo.joshpuckett.me) by Josh
  Puckett, with its roundness axis and stylistic sets.
- `CoilTypography.inter()`, for [Inter](https://rsms.me/inter/) by Rasmus
  Andersson.

Both are under the SIL Open Font License 1.1. To use one, add its variable
font to the app with its license, declare it in the app's `pubspec.yaml`,
and pass the preset to the theme:

```yaml
flutter:
  fonts:
    - family: Allo
      fonts:
        - asset: fonts/AlloVariable.ttf
```

```dart
CoilThemeData(typography: CoilTypography.allo(roundness: 70))
```

In debug builds, coil reports a typography whose font the app doesn't
bundle. For any other font, `CoilTypography.from(TextStyle(fontFamily:
'Brand'))` puts coil's type scale on it. The catalog in `example/` bundles
both fonts and shows the setup.

## Icons

coil bundles no icons. Slots take any widget and are styled through
Flutter's `IconTheme`. The few glyphs coil draws itself (check, dash, copy, ×,
alert, chevrons, send, stop) can be swapped for your own icon set in one
place, `CoilThemeData.icons`. [`doc/icons.md`](doc/icons.md) has complete
sets for Lucide and Material Symbols.

## Accessibility

Every component ships with:

- semantics for its role, name and state;
- full keyboard operation, safe for IME composition;
- a focus ring that shows only after keyboard use;
- text scaling up to 2×, with controls growing to fit;
- high contrast, bold text and right-to-left layouts;
- reduced motion: spatial springs become instant and fades stay;
- 44 pt touch targets on touch.

Hover only comes from pointers that can hover, and a press clears on release,
cancel or scroll, so a touch never leaves a highlight behind.

## Ejecting a component

To edit a component's look, copy it into your app with `coil_cli`, a dev
dependency:

```sh
flutter pub add dev:coil_cli
dart run coil_cli:eject --list
dart run coil_cli:eject button
dart run coil_cli:update button   # later: three-way merge of coil's changes
```

The app then imports its generated `lib/coil.dart` instead of
`package:coil/coil.dart`. Behavior stays in coil's primitives, so only the
look and composition are copied. Components ejected together, or one after
another, use each other's copies.

The first eject can give the copies your app's names:
`dart run coil_cli:eject --all --prefix Acme` turns `CoilButton` into
`AcmeButton`, and `coil_cli:update` renames coil's new version the same way
before merging.

[`SKILL.md`](SKILL.md) covers using, theming, ejecting and updating in full,
for people and for coding agents.

## Limitations

- Without Material or Cupertino localizations in the app, the text selection
  toolbar's labels are English in every locale.
- A modal pushed with `CoilModalRoute` is a route: it doesn't rebuild with the
  widget that pushed it. Use `CoilModalPage` in `Navigator.pages` for that.

## Credits

coil is inspired by **[Fluid Functionalism](https://www.fluidfunctionalism.com)**
by Micka Touillaud (MIT): its spacing rhythm, type, color restraint,
travelling hover highlight and merged selections. coil is its own system. The
original license is in [`LICENSE.fluid-functionalism`](LICENSE.fluid-functionalism).
