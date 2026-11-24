# Coil

A Flutter design system built on [Motor](https://pub.dev/packages/motor) motion. Coil works under any `WidgetsApp` with no Material or Cupertino app shell, and adapts to mouse, touch, keyboard, and screen readers on every platform.

- **Complete component set:** Controls, forms, menus, overlays, tables, sidebars, calendars, and chat interfaces.
- **Physics-based transitions:** Every animation runs on a spring, so interrupting a transition carries its velocity instead of restarting.
- **Consistent look, native feel:** One visual language across platforms, while respecting platform conventions for menus, scrolling, text selection, haptics, and back gestures.
- **Themeable and ejectable:** Customize colors, shapes, typography, motion, and icons from one theme — or copy any component into your app to edit it directly.

[Open the interactive catalog](https://whynotmake-it.github.io/rivership/#/coil) to try every component in your browser.

> **Pre-release:** Coil's API may change before 1.0. Requires Flutter 3.47 or later.

## Installation

```sh
flutter pub add coil
```

## Quick start

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

- `CoilTheme` is optional; without it, components follow the platform brightness automatically.
- Text and icons are passed as `Widget` slots (`child`, `leading`, `label`), so pass `Text('Save')` rather than a bare `String`.
- `package:coil/coil.dart` exports everything. To keep imports narrower, use `package:coil/foundation.dart`, `package:coil/primitives.dart`, or a single component library such as `package:coil/button.dart`.

## Components

| Category | Components |
|---|---|
| Controls | `CoilButton`, `CoilBadge`, `CoilKbd`, `CoilCheckbox`, `CoilSwitch`, `CoilSlider`, `CoilRangeSlider`, `CoilInput` (and `.multiline`), `CoilInputGroup`, `CoilInputCopy`, `CoilSkeleton` |
| Forms | `CoilField` (with `CoilFieldSet`, `CoilFieldGroup`, `CoilFieldSeparator`), `CoilCheckboxGroup`, `CoilRadioGroup`, `CoilToggleGroup`, `CoilTabs`, `CoilSelect`, `CoilMultiSelect`, `CoilCombobox`, `CoilCalendar`, `CoilDatePicker` |
| Menus & overlays | `CoilDialog`, `CoilSettingsDialog`, `CoilTooltip`, `CoilDropdown`, `CoilContextMenu`, `CoilCommandMenu` |
| Layout & display | `CoilAccordion`, `CoilCard`, `CoilTable`, `CoilDataTable`, `CoilBanner`, `CoilBreadcrumb`, `CoilScrollArea`, `CoilCarouselDots`, `CoilFileThumbnail`, `CoilReveal`, `CoilSidebarScaffold` (with `CoilSidebar`) |
| Chat | `CoilChatMessage`, `CoilInputMessage`, `CoilQueuedStack`, `CoilThinkingSteps`, `CoilThinkingIndicator`, `CoilAskUserQuestions` |

The underlying building blocks — `CoilInteraction`, `CoilFocusRing`, `CoilPopover`, `CoilSheetRoute`, `CoilTextFieldCore`, and friends — are public in `package:coil/primitives.dart` so you can build custom components with the same behavior. Browse every component live in [`example/`](example) or [online](https://whynotmake-it.github.io/rivership/#/coil).

## Theming

Start with `CoilThemeData` before overriding individual widgets:

```dart
CoilTheme(
  data: CoilThemeData(
    shape: CoilShape.pill,
    typography: CoilTypography.inter(),
  ),
  child: app,
)
```

- **Colors:** `CoilColors.fromSeed(brightness: Brightness.light, brand: myColor)` generates a complete palette from a brand color.
- **Shape:** `CoilShape.rounded`, `.pill`, or `.sharp` (every rounded corner is a superellipse).
- **Motion:** `CoilMotion` holds the spring tokens, customizable app-wide, per subtree with `CoilTheme.override`, or per component.
- **Input tier:** `CoilTier` switches between pointer and touch sizing (follows the platform by default).
- **Per-component styles:** Call `withComponentStyle(CoilButtonStyle(...))` to restyle one component type everywhere.

### Frame rate

Coil's springs tick every display frame by default. Wrap your app or a subtree in `TickerRateScope` (re-exported alongside `TickerRate` from `package:coil/coil.dart`) to cap springs to a fixed rate — helpful for saving work on 120 Hz screens or low-priority surfaces. Reduced motion still applies.

```dart
TickerRateScope(
  rate: TickerRate.fps(30),
  child: CoilTheme(
    data: CoilThemeData(shape: CoilShape.pill),
    child: app,
  ),
)
```

## Fonts

Coil doesn't bundle any font files so your app never ships unused assets. By default it uses the platform's system UI font. Two presets are tuned for popular variable fonts:

- `CoilTypography.allo()` for [Allo](https://allo.joshpuckett.me) by Josh Puckett (including its roundness axis and stylistic sets).
- `CoilTypography.inter()` for [Inter](https://rsms.me/inter/) by Rasmus Andersson.

Both fonts are licensed under the SIL Open Font License 1.1. Add the font file and its license to your app, register it in `pubspec.yaml`, and pass the preset to `CoilThemeData`:

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

In debug builds, Coil warns if a preset's font isn't bundled in the app. To apply Coil's type scale to any other font, use `CoilTypography.from(const TextStyle(fontFamily: 'Brand'))`. See [`example/`](example) for a complete setup bundling both fonts.

## Icons

Coil doesn't bundle an icon pack. Icon slots accept any `Widget` and inherit Flutter's `IconTheme`. The small set of built-in glyphs (check, dash, copy, close, alert, chevrons, send, stop) can be replaced in one place via `CoilThemeData.icons`. See [`doc/icons.md`](doc/icons.md) for ready-to-use mappings for Lucide and Material Symbols.

## Accessibility

Every component includes:

- Semantics for role, name, and state.
- Full keyboard navigation that stays safe during IME composition.
- A focus ring that appears only during keyboard navigation.
- Text scaling up to 2×, with controls expanding to fit.
- High-contrast, bold-text, and right-to-left (RTL) support.
- Reduced-motion support (spatial springs become instant while fades remain).
- 44 px touch targets on touch devices.

Hover highlights only trigger for hover-capable pointers, and pressed states clear on release, cancel, or scroll so touch interactions never leave sticky highlights behind.

## Ejecting components

If you want full control over a component's visuals, copy it into your app with [`coil_cli`](../coil_cli) as a dev dependency:

```sh
flutter pub add dev:coil_cli
dart run coil_cli:eject --list
dart run coil_cli:eject button
dart run coil_cli:update button   # Later: three-way merge of upstream Coil changes
```

Your app then imports its generated `lib/coil.dart` instead of `package:coil/coil.dart`. Interaction behavior stays in Coil's primitives, so only visual styling and composition are copied into your project, and ejected components automatically reference each other's local copies.

You can also rename copies on the first eject — for example, `dart run coil_cli:eject --all --prefix Acme` renames `CoilButton` to `AcmeButton`, and `coil_cli:update` applies the same rename before merging future updates.

## Documentation

- [`DESIGN.md`](DESIGN.md) — Coil's design specification: color, typography, spacing, shape, motion, interaction rules, and component anatomy.
- [`doc/icons.md`](doc/icons.md) — Icon role map, Lucide and Material Symbols setups, and animated icons.
- [`SKILL.md`](SKILL.md) — End-to-end guide to using, theming, ejecting, updating, and testing Coil (for developers and coding agents).

## Limitations

- Without Material or Cupertino localizations registered in the app, text selection toolbar labels default to English in every locale.
- A modal pushed with `CoilModalRoute` is a standard `Navigator` route and doesn't rebuild when its caller rebuilds; use `CoilModalPage` in `Navigator.pages` when you need reactive updates.

## Credits

Coil is inspired by **[Fluid Functionalism](https://www.fluidfunctionalism.com)** by Micka Touillaud (MIT) — particularly its spacing rhythm, typography, color restraint, travelling hover highlight, and merged selections. Coil is an independent system; the original license is included in [`LICENSE.fluid-functionalism`](LICENSE.fluid-functionalism).
