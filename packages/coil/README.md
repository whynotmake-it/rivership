# coil

A Flutter design system built on [Motor](../motor) springs. It works under
any `WidgetsApp` (no Material or Cupertino app shell) and adapts to pointer
and touch, keyboard and screen readers on every platform.

> Pre-release. coil depends on unreleased Motor 2.0 and is not published.
> It needs Flutter 3.47 or later.

## Credits

coil is inspired by **[Fluid Functionalism](https://www.fluidfunctionalism.com)**
by Micka Touillaud (MIT). Its spacing rhythm, type, color restraint, the
travelling hover highlight and merged selections are the starting point for
coil's look. coil is its own system: it doesn't aim for pixel or timing
parity, and its motion tokens are its own. The original license is in
[`LICENSE.fluid-functionalism`](LICENSE.fluid-functionalism).

The bundled font is [Inter](https://rsms.me/inter/), © The Inter Project
Authors, SIL Open Font License 1.1.

## Using it

```dart
import 'package:coil/coil.dart';

CoilTheme(
  data: CoilThemeData.light,
  child: CoilButton(onPressed: save, child: const Text('Save')),
)
```

`CoilTheme` is optional; without it components follow the platform
brightness. Import `package:coil/foundation.dart`, `primitives.dart` or a
single component's library (`package:coil/button.dart`) to depend on less.

Read [`doc/api_guide.md`](doc/api_guide.md) before adding to the API.

## Layers

| Layer | Library | Holds |
|---|---|---|
| Foundation | `foundation.dart` | `CoilThemeData`/`CoilTheme`, `CoilColors`, `CoilMotion`, `CoilMetrics` (`CoilTier` × `CoilSize`), `CoilTypography`, `CoilShape`, `CoilHaptics`, `CoilInputModality`, `CoilAdaptiveScope` |
| Primitives | `primitives.dart` | `CoilInteraction`, `CoilFocusRing`, `CoilRovingFocus`, `CoilTypeahead`, `CoilActiveItemController`, `CoilMotionLayer` with `CoilHoverRegion`, `CoilHighlight`, `CoilSelectionBlocks` (merge/split), `CoilLayerPaint`, `CoilHoverHighlight`, `CoilBlurFade`, `CoilPopover`, `CoilSheetRoute`, `CoilAdaptivePopup`, `CoilTextFieldCore`, `CoilFieldScope`, `CoilLineBox`, `CoilDrawnGlyph`, `CoilChoiceGroup`, `CoilChoiceItem`, `CoilChoiceRow`, `CoilPopoverSurface`, `CoilActionList`, `CoilCollapsible`, `CoilDisclosureTrigger`, `CoilScrollbar`, `CoilScrollEdgeFade`, `CoilScrollSpring` |
| Components | one library each | `CoilButton`, `CoilBadge`, `CoilSkeleton`, `CoilCheckbox`, `CoilSwitch`, `CoilSlider`, `CoilTabs`, `CoilInput` (and `.multiline`), `CoilInputGroup`, `CoilInputCopy`, `CoilField` (with `CoilFieldSet`, `CoilFieldGroup`, `CoilFieldSeparator`), `CoilCheckboxGroup`, `CoilRadioGroup`, `CoilToggleGroup`, `CoilSelect`, `CoilMultiSelect`, `CoilScrollArea`, `CoilAccordion`, `CoilThinkingSteps`, `CoilThinkingIndicator`, `CoilCard` (with `CoilCardGroup`), `CoilTable`, `CoilBanner`, `CoilBreadcrumb`, `CoilChatMessage`, `CoilCarouselDots` |

Components reach pointers, overlays, haptics and travelling motion only
through primitives. `test/architecture/import_rules_test.dart` enforces it,
so the interaction rules hold in ejected copies too.

## Interaction rules

- Hover only from pointers that can hover (mouse, trackpad, hovering pen).
  A touch never leaves a highlight behind.
- Press shows on touch-down, clears on release, cancel or scroll, and a
  quick tap still shows it for `CoilMotion.minPressDuration` (90 ms).
- The focus ring shows only after keyboard use; taps and clicks hide it.
  Text fields show their focus border while editing.
- Lists have an active item, separate from focus and hover: arrows, hover
  and typeahead move it, Enter acts on it.
- The tier latches by platform (desktop → pointer sizes, phone/tablet →
  touch sizes); each event's pointer kind decides hover and press.
- Short menus stay anchored on phones; long, searchable and multi-select
  lists open as sheets (`CoilAdaptivePopup.phonePresentation`).
- Native first: the iOS system edit menu, the browser's menu on web.
  Selection handles and toolbars come from `material_ui`/`cupertino_ui`,
  used only inside `CoilTextFieldCore`.

## Motion

Every token is a Motor spring, exits included, so an interrupted transition
keeps its velocity. Tokens are theme data: change them app-wide, per
subtree (`CoilTheme.override`), per component (`motion:`) or per track
(`motions: {.thumb: …}`, or `CoilThemeData.trackMotions` app-wide). Reduced motion is applied last: spatial springs become
instant, fades stay.

| Token | Default (`CupertinoMotion`) | Moves |
|---|---|---|
| `quick` / `quickExit` | 100 ms / 80 ms, no bounce | hover highlight, press collapse |
| `standard` / `standardExit` | 180 ms / 140 ms, no bounce | tab pill, switch thumb, merge/split, popovers |
| `gentle` / `gentleExit` | 340 ms bounce 0.1 / 260 ms | sheets, dialogs |
| `fade` / `fadeExit` | 120 ms / 90 ms, no bounce | opacity, color, check drawing |

## Shapes

Every rounded shape is a superellipse (`RoundedSuperellipseBorder`,
`RSuperellipse`), pills included; an architecture test keeps it that way.

## Icons

coil bundles no icons. Slots take any widget and are styled through
Flutter's `IconTheme`, with `applyTextScaling` on so icons grow with text. Glyphs a component draws itself (check, chevron,
spinner) can be replaced through a slot or builder.

## Tests

Run with Flutter 3.47: `flutter test` in this package.

Each component's file runs the shared checks from `test/src/`:

- `matrixGoldenTest` (goldens in `test/goldens/matrix/`): light/dark ×
  pointer/touch, each at text scale 1, 1.5 and 2, in RTL and high contrast,
  with real Inter at 2x; overlays open as popover and sheet.
- `expectCoilPattern`: semantics, keyboard and focus-visible, in LTR and
  RTL.
- `inkCenteringTests`: label ink centered within 1 px at every tier, size
  and text scale.

The M0 components still run these from the shared
`golden_matrix_test.dart`, `patterns_test.dart` and
`label_alignment_test.dart`.
- `test/text_field_core_ime_test.dart`: IME composition guards, the iOS
  system menu, toolbars under a bare `WidgetsApp`.
- `test/motion_theme_test.dart`: motion tokens changed at runtime.
- `test/goldens/web_reference/`: Fluid Functionalism screenshots, for
  reference only.

## Known gaps

- `stupid_simple_sheet` uses one motion for both directions and keeps the
  drag's fling velocity on dismiss, so sheets exit on `gentle`, not
  `gentleExit`. An `exitMotion` hook upstream would fix it.
- `style:` classes per component type and instance are planned for M1.
- Without Material or Cupertino localizations in the app, the text
  selection toolbar's labels are English in every locale.
- Desktop text fields show Flutter's own right-click toolbar, not a
  coil-styled menu; that needs the ContextMenu component.
- An open sheet is a route: it doesn't rebuild with the widget that
  opened it. An open popover does.
