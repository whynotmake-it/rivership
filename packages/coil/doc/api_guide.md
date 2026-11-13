# coil API guide

Read this before adding or changing a public API in `coil`. Every component
follows it, and a reviewer may reject code that doesn't. When the guide and
the code disagree, fix one of them in the same change and add a line to the
[settled-choices log](#settled-choices-log).

coil is inspired by [Fluid Functionalism](https://www.fluidfunctionalism.com)
(MIT), but it is its own system. Names follow Flutter's widgets layer first,
then this guide, and FF's web names last.

## 1. Layers and imports

| Layer | Public library | May import |
|---|---|---|
| Foundation: tokens, theme, motion, metrics, input modality, adaptive scope | `package:coil/foundation.dart` | Flutter (`widgets`, `foundation`, `painting`, `services`, `gestures`, `rendering`, `scheduler`, `physics`, `semantics`), `motor` |
| Primitives: interaction, focus, active item, motion layer, anchor, presence, sheet, adaptive popup, text-field core | `package:coil/primitives.dart` | the above, foundation, other primitives, `stupid_simple_sheet` |
| Components: look and composition | `package:coil/<component>.dart` | the above, `package:coil/foundation.dart`, `package:coil/primitives.dart`, other components' **public** libraries, `motor_widgets` |

- A component never imports another component's `src/`, and never imports a
  primitive's or foundation's `src/` file. It goes through the public
  libraries, so an ejected copy compiles with the same imports.
- Components don't use `MouseRegion`, `onTapDown`, `HapticFeedback`,
  `FocusManager.highlightMode`, `OverlayPortal`, `RawMenuAnchor`,
  `PopupRoute` or Motor controllers for travel or presence. The primitive
  for each is listed in §3.
- `package:material_ui` and `package:cupertino_ui` are imported by exactly
  one file, `lib/src/primitives/text_field_core.dart`, and none of their
  types appear in coil's public API. `package:flutter/material.dart` and
  `package:flutter/cupertino.dart` are never imported.
- `test/architecture/import_rules_test.dart` enforces all of the above.

`package:coil/coil.dart` exports everything for apps that don't care.

## 2. Same idea, same name

### Types

| Idea | Name | Replaces (research 02 / 03 / spikes) |
|---|---|---|
| Theme data, the whole token set | `CoilThemeData` | `FluidThemeData` |
| Theme widget and lookups | `CoilTheme`, `CoilTheme.of`, `.motionOf`, `.metricsOf`; subtree deltas with `CoilTheme.override` | `FluidTheme.sizesOf`, mobile spike's second `FluidTheme` |
| Colors | `CoilColors` | `FluidColors` (two copies) |
| Motion tokens | `CoilMotion` (springs only: `quick`, `standard`, `gentle`, their `…Exit` springs, `fade`, `fadeExit`) | 02 `FluidSprings`/`FluidMotion`/`FluidMotionTier`, 03 `FluidMotionData`/`FluidMotionTokens`/`FluidSpring`, spikes' `FluidMotionThemeData` |
| Input tier (what sizes are designed for) | `CoilTier { pointer, touch }` | 02 `FluidDensity`, 03 `FluidSize` (pointer half), core `FluidTier{desktop,touch}`, mobile `FluidInputMode` |
| Size step | `CoilSize { regular, compact }`, parameter `size:` | core `FluidDensity`, 03 `FluidSize` |
| Resolved dimensions | `CoilMetrics` | core `FluidSizes`, mobile `FluidMetrics` |
| Adaptive pins for a subtree | `CoilAdaptiveScope(tier:, size:, presentation:)` | `FluidSizeScope`, `FluidAdaptiveScope` |
| Last input modality (focus-visible) | `CoilInputModality.instance`, `CoilModality { keyboard, pointer }` | core `FluidInputModality`, mobile `FluidKeyboardModality`, 02 `FluidInputMode` |
| Can this pointer hover? | `CoilInputModality.canHover(kind)` | `fluidCanHover` |
| Interaction states for one control | `CoilInteraction` (widget), `CoilInteractionDetector` (lower level) | `FluidPressable`, 03 `FluidInteraction` |
| Popover vs sheet | `CoilPresentation { popover, sheet }` | none |
| Corner family | `CoilShape` (`.rounded`, `.pill`, `.sharp` or your own `CoilRadii` per tier) | none |
| Type | `CoilTypography`, `CoilTypeStep`, `CoilWeight` | `FluidTypographyThemeData`, `FluidTypeRole` |

Rules:

- Every public type starts with `Coil`. Enums too, so dot shorthands read
  well: `CoilButton(variant: .ghost, size: .compact)`.
- Data classes don't end in `ThemeData` unless they are the theme
  (`CoilThemeData`). A token group is a plain name (`CoilColors`,
  `CoilMotion`, `CoilMetrics`), like `ColorScheme` and `Typography`.
- Lookups are static methods on `CoilTheme`, not on the data class.

### Parameters

| Idea | Name | Notes |
|---|---|---|
| The control's current value | `value` | single value: `bool`, `T`, `int` index |
| A set of values | `values` | `Set<T>` |
| Report a new value | `onChanged` | always the **new** `value`/`values`, never a delta. Null disables the control |
| Activate (buttons, rows) | `onPressed` | null disables |
| Disabled without a callback | `enabled` | only where Flutter has it too (`CoilInput`, mirroring `TextField`) |
| Size step | `size: CoilSize?` | null inherits from `CoilAdaptiveScope` |
| Visual variant | `variant: Coil<Name>Variant` | enum |
| Main content of a single-content widget | `child` | |
| Text identity of an item in a collection | `label: String` | used for typeahead, semantics and the default visual |
| Visual override of an item | `child: Widget?` on the item | replaces the default `Text(label)` |
| Leading / trailing slot | `leading`, `trailing` | any `Widget`, styled by `IconTheme` and `DefaultTextStyle` |
| Icon-only content | `icon` | named constructor `.icon(...)` where a widget can be icon-only |
| Drawn glyph replacement | `<glyph>Builder` or a `Widget?` slot | e.g. `CoilCheckbox.glyphBuilder`, `CoilSelect.checkmark` |
| Per-instance motion | `motion: CoilMotion?`, plus `motions: Map<Coil<Name>Track<Object>, Motion>?` on multi-track components | see §6 |
| Per-instance style | `style: Coil<Name>Style?` | see §6 |
| Overlay presentation | `presentation: CoilPresentation?` | null lets `CoilAdaptivePopup` decide |
| Focus | `focusNode`, `autofocus` | as in Flutter |
| Observable/forceable states | `statesController: WidgetStatesController?` | as in Flutter's buttons |
| Accessible name when the visual has none | `semanticLabel` | |
| Invalid input | `invalid: bool` | a real yes/no state (`aria-invalid`) |

## 3. Primitives a component must use

| Need | Use |
|---|---|
| hover, press, focus-visible, disabled | `CoilInteraction` (or `CoilInteractionDetector` for a control that owns its gestures) |
| focus ring | `CoilFocusRing` |
| arrows/Home/End between items, one tab stop | `CoilRovingFocus` |
| type-to-jump | `CoilTypeahead` |
| the item Enter acts on | `CoilActiveItemController` |
| which item is lit (pointer, keyboard focus) | `CoilHoverRegion`, read with `CoilHoverRegion.maybeOf` |
| travelling highlight, pills, merge/split selection | `CoilHoverHighlight`, or your own `CoilMotionLayer` with `CoilHighlight` and `CoilSelectionBlocks` items (`CoilLayerPaint` for custom drawing). Items are immutable and built in `build`; the layer owns the animation. Inside a scroll view, put it in the scrolled content |
| anchored popover | `CoilPopover` via `CoilAdaptivePopup` |
| sheet | `CoilSheetRoute` via `CoilAdaptivePopup` |
| popover or sheet? | `CoilAdaptivePopup.presentationOf` (the hybrid phone rule) |
| editable text | `CoilTextFieldCore` |
| a raised surface (fill, shadow, edge) and its level scope | `CoilSurface` |
| enter/exit of a popover | `CoilBlurFade` (via `CoilAdaptivePopup`) |
| haptic feedback | `CoilHaptics.play(context, event)` |
| cross-fades and size changes in place | `motor_widgets`' `MotionSwitcher`, `MotionSizeSwitcher`, `MotionSize`, with `CoilBlurFade` as the `transitionBuilder` |

## 4. Enums over booleans

A boolean parameter is allowed only for a true yes/no state of the control
(`value` of a switch, `invalid`, `loading`, `selected`, `autofocus`). Anything
that picks one of several looks or behaviors is an enum, even when it has two
values today:

- `CoilTabs(labels: CoilTabLabels.selected)`, not `activeLabel: true`.
- `CoilButton(variant: .ghost)`, not `ghost: true`.
- `CoilPresentation.sheet`, not `useSheet: true`.

Two booleans that can contradict each other are a smell. Where Flutter
already has a shape for a state, coil uses it: `CoilCheckbox` takes
`value: bool?` + `tristate`, like `Checkbox`.

## 5. Slots over flags

- A component that shows something optional takes a `Widget?` slot, not a
  `showX: bool`. `leading: null` means no leading slot.
- coil bundles no icons. Slots take any widget; the component styles them
  with `IconTheme` (size, color, `weight`, `applyTextScaling: true`) and
  `DefaultTextStyle`. A custom slot glyph that paints itself should size
  with `CoilIconSize.of(context)` so it grows with text like `Icon` does.
- Glyphs a component draws itself (checkbox tick, chevron, spinner) are
  private painters, replaceable through a slot or a builder.
- State-dependent slot content uses a builder
  `Widget Function(BuildContext, Set<WidgetState>)`.

## 6. Overrides: theme, `style:`, `motion:`

Resolution order, lowest to highest. Each layer is applied on top of the
previous one when a component builds:

1. Package defaults: `CoilThemeData.light` / `.dark` (picked by platform
   brightness when there is no `CoilTheme`).
2. Platform tier: `CoilTier` from `CoilAdaptiveScope`, else the theme's
   `tier`, else the platform (desktop OS → pointer, phone/tablet → touch).
   It selects among the adaptive defaults, it doesn't merge.
3. App-wide: the root `CoilTheme(data:)`.
4. Subtree: `CoilTheme.override(transform: (t) => t.copyWith(...))`. The
   transform runs on the parent's data, so a later change at the root still
   flows through.
5. Per-component-type: the theme's style for the component's style type
   (`CoilThemeData.components`, set with `withComponentStyle`, which merges
   onto an existing entry) and its `trackMotions`.
6. Per instance: the component's `style:`, `motion:` and `motions:`
   parameters.
7. High contrast (`MediaQuery.highContrastOf`): applied by `CoilTheme.of`.
8. Reduced motion (`MediaQuery.disableAnimationsOf`): applied **last** by
   `CoilTheme.motionOf`, on top of whatever 1–7 produced.

### Style classes

Every component has a `Coil<Name>Style extends CoilComponentStyle<…>` in
`src/components/<name>/<name>_style.dart`, exported from its library:

- every field is nullable; null means "use the default";
- `factory Coil<Name>Style.fallback(CoilThemeData theme, CoilMetrics
  metrics, …)` computes every field from tokens, so a token change flows
  into any field the app didn't set;
- `merge(other)`: `other`'s non-null fields win (text styles merge);
- value equality through `props`;
- state-dependent colors are `WidgetStateProperty<Color?>`, resolved with
  the states the style's doc lists (`hovered`, `pressed`, `selected`,
  `focused`, `error`, `disabled`);
- the component resolves
  `fallback(...).merge(CoilTheme.styleOf<S>(context)).merge(widget.style)`
  once per build and reads only that.

Styles hold look only (colors, radii, text styles, sizes). Behavior,
motion (`motion:`/`motions:`) and adaptive decisions are never style
fields.

`motion:` takes a whole `CoilMotion` (the token set). Write it as a copy of
the inherited tokens when only one field changes:

```dart
CoilSwitch(
  value: on,
  onChanged: (v) => setState(() => on = v),
  motion: CoilTheme.of(context).motion.copyWith(
    standard: const CupertinoMotion(duration: Duration(milliseconds: 300)),
  ),
)
```

Multi-part components declare a track class and take per-track motions
(PLAN §15; `motor_widgets` does the same with `MotionContainerTrack`):

- `final class CoilSwitchTrack<T extends Object> extends Track<T>` with a
  private constructor (`final`, not `sealed`) and the component's tracks as
  `static final` fields on it: `CoilSwitchTrack.thumb`, `.squish`, `.tint`.
  They are the real Motor tracks the component animates, carry a
  `debugLabel`, and have no baked-in motion.
- `motion:` is the default for every track (the token set, `CoilMotion`);
  `motions: Map<CoilSwitchTrack<Object>, Motion>?` overrides single tracks.
  Typing the keys by the component's track class means only its tracks
  compile, and dot shorthand reads well:

  ```dart
  CoilSwitch(value: on, onChanged: setOn, motions: {.thumb: const .bouncySpring()})
  ```
- Theme-level per-component overrides use the same keys in
  `CoilThemeData.trackMotions` (`{CoilSwitchTrack.thumb: …}`).
- Resolution for one track, through `CoilTheme.trackMotionOf`: the
  instance's `motions` entry, else the theme's `trackMotions` entry, else
  the token the component maps the track to (`thumb` → `standard`,
  `squish` → `quick`, `tint` → `fade`). Reduced motion still makes spatial
  tracks instant.
- Maps compare by value, so a literal rebuilt every frame never redirects a
  running animation.
- There is no per-dimension map and no per-component motion class
  (`CoilSwitchMotion(thumb: …)` is not used).

Components read motion with `CoilTheme.motionOf(context, override: widget.motion)`
**every time they start an animation** and pass it to that animation. They
never bake a motion into a `Track` default or a controller constructor, so a
theme change applies to the next animation without recreating anything.

Which token for what:

| Token | Moves |
|---|---|
| `quick` / `quickExit` | small travel: the hover highlight, press collapse, thumb squish |
| `standard` / `standardExit` | indicators that must land: tab pill, switch thumb, merge/split, popovers |
| `gentle` / `gentleExit` | large surfaces: sheets, dialogs, panels |
| `fade` / `fadeExit` | opacity and color: tints, focus rings, label color, check drawing |

Reduced motion makes every spatial token instant and keeps `fade`/`fadeExit`.
So a component must animate opacity and color with `fade`, never with a
spatial token.

## 7. Controlled and uncontrolled; controllers

- Value controls are **controlled**: `value` + `onChanged`, like Flutter's
  `Checkbox` and `Switch`. The widget never keeps its own copy of the value.
- Complex state that a parent may want to drive lives in a controller with
  one shape: `Coil<Name>Controller extends ChangeNotifier` (or
  `ValueNotifier<T>` when the state is one value), an optional
  `controller:` parameter, and an owned instance when it is null (the
  `TextField` pattern). Flutter's controllers are reused where they exist:
  `TextEditingController`, `UndoHistoryController`, `WidgetStatesController`,
  `ScrollController`.
- coil's controllers: `CoilActiveItemController` (a list's active item)
  and `CoilPopupController` (open/close a popup; `open()` resolves with a
  `CoilPopupCloseReason`). Both are `ChangeNotifier`s passed as
  `controller:`; a component without one manages its own state.
- `items`/`options` are used only for collections whose entries are data
  (`CoilSelect.options`, `CoilCheckboxGroup.options`, `CoilTabs.tabs`).
  Entries carry their `value: T`; the component is generic in `T` and
  reports values, never indexes. `CoilOption<T>` (foundation) is the shared
  entry for choices. Composition (`children`) is used
  when entries are arbitrary widgets.

## 8. Platform behavior

- Hover only from hover-capable pointers (`CoilInputModality.canHover`).
- Press shows on touch-down, clears on up/cancel/scroll, and stays visible at
  least `CoilMotion.minPressDuration` (90 ms) after a quick tap.
- The focus ring shows only after keyboard use (`CoilModality.keyboard`).
- Native first: iOS `SystemContextMenu` for text, the browser's menu on web,
  platform keyboards and autofill. Material/Cupertino selection handles and
  toolbars only inside `CoilTextFieldCore`.

Look:

- Every rounded shape is a superellipse: `ShapeDecoration` with
  `RoundedSuperellipseBorder`, `ClipRSuperellipse`, `drawRSuperellipse`.
  Pills use radius = height / 2. `test/architecture` fails on rounded rects.
- Icons scale with text: every `IconThemeData` coil provides sets
  `applyTextScaling: true`, and drawn glyphs size with
  `CoilIconSize.of(context)`. Glyph-like boxes (checkbox) scale too; gaps
  don't.
- Sizes and radii are theme data: `CoilThemeData.metrics` (a
  `CoilMetricsTable`) and `CoilThemeData.shape`.

## 9. Settled-choices log

| Date | Choice | Why |
|---|---|---|
| 2026-11-13 | Package `coil`, prefix `Coil` | PLAN §14 |
| 2026-11-13 | One name per idea (§2) | research 02 and 03 disagreed |
| 2026-11-13 | Tier names `pointer`/`touch`, not `desktop`/`touch` | an iPad with a trackpad is still `touch` tier; the name says what the sizes are designed for, not the device |
| 2026-11-13 | Springs only; no `FluidMotionDelta`, `FluidSpring`, `fromWeb`, no curves | PLAN §12; exits are tighter springs so a reversal keeps velocity |
| 2026-11-13 | Opacity/color use `fade`/`fadeExit`, which survive reduced motion | reduced motion is "fewer and gentler", not none |
| 2026-11-13 | The tier latches by platform; each event's pointer kind decides hover and press | PLAN §3 |
| 2026-11-13 | One adaptive scope `CoilAdaptiveScope` for tier, size and presentation pins | the spikes had `FluidSizeScope` and `FluidAdaptiveScope` doing overlapping jobs |
| 2026-11-13 | Value controls are controlled; null `onChanged` disables | Flutter idiom |
| 2026-11-13 | `CoilSelect<T>` and `CoilMultiSelect<T>` are two widgets | one `onChanged` name with one type per widget, instead of `onValuesChanged` |
| 2026-11-13 | Tabs: `value` + `onChanged`, `labels: CoilTabLabels` | same idea, same name; enums over booleans |
| 2026-11-13 | `CoilCheckbox` takes `value: bool?` + `tristate`, like `Checkbox`; null is the dash | no contradicting booleans |
| 2026-11-13 | Icons and glyphs scale with text (§8) | user review of M0 |
| 2026-11-13 | Superellipses only (§8) | user review of M0 |
| 2026-11-13 | `expectCoilPattern` stays internal to coil's tests; no export and no `coil_test` package yet (`TODO(coil-eject)`) | user, 2026-11-13 |
| 2026-11-13 | Every component has a style class (§6) | landed together before the waves |
| 2026-11-13 | Tabs and groups are generic in `T`; choices are `CoilOption<T>` (§7) | indexes leak layout into app state |
| 2026-11-13 | Theme-level track motions stay one flat `trackMotions` map | tracks are unique objects; revisit only if per-type styles need it |
| 2026-11-13 | No per-kind presentation pin | YAGNI; a component's `presentation:` covers the exceptions |
| 2026-11-13 | `CoilPopupController`, like `MenuController`; `open()` resolves once with a `CoilPopupCloseReason` (§7) | overlay acceptance tests |
| 2026-11-13 | `CoilButton.selected` (was `active`) | matches `WidgetState.selected` |
| 2026-11-13 | Collection items carry `label: String` plus optional `child` | typeahead and semantics need text |
| 2026-11-13 | `CoilTheme.override(transform:)` for subtree changes | root changes still flow through |
| 2026-11-13 | The brand color is `CoilColors.brand` (was `fluidAccent`) | `accent` already names FF's neutral `--accent` |
| 2026-11-13 | Groups take `options` (data entries) and `values`; `CoilRadioGroup` takes `value`. All three take `semanticLabel` | data entries use `options`; sets use `values` |
| 2026-11-13 | `motion:` sets the tokens; `motions:` overrides single tracks (§6) | PLAN §15 |
| 2026-11-13 | `CoilBlurFade` is the overlay enter/exit, also as a `MotionSwitcher` transition | `motor_widgets` holds only Flutter equivalents |
| 2026-11-13 | A text field shows its focus border however it was focused | as `:focus-visible` does for inputs; every other control shows the ring only after keyboard use |
| 2026-11-13 | `CoilSlider` follows Flutter's `Slider` (`value`, `onChanged`, `min`, `max`, `divisions`, `onChangeStart`, `onChangeEnd`) with two differences: `label` is the row's `Widget`, not the value-indicator string, and `valueFormatter` replaces both that string and `semanticFormatterCallback`. The pill is a `variant`, not a size | a Flutter user would guess `label` is a string; size must not change anatomy |
| 2026-11-13 | `CoilHoverRegion` only tracks state; `CoilHoverHighlight` paints the default highlight | one job per widget; callers update their own painters in build |
| 2026-11-13 | Metrics and radii live in the theme (`CoilMetricsTable`, `CoilShape` class) | runtime-customizable, like every other token |
| 2026-11-13 | The popover picks its side by laying out its content | no size estimates |
| 2026-11-13 | Popovers are `OverlayPortal` descendants of their owner; sheets stay routes | same-frame anchoring and live values; a sheet doesn't anchor |
| 2026-11-13 | Haptics are theme data (`CoilThemeData.haptics`, null for the platform's) | apps can remap or silence them |
| 2026-11-13 | `onDismissed` reports a finished dismissal (`CoilCard`, like `Dismissible`); `onDismissRequested` asks the owner to hide a controlled widget (`CoilBanner`) | one name, one contract |
| 2026-11-13 | `CoilAccordion.single` / `.multiple` are one widget with two constructors | the value type differs, the widget doesn't; `CoilSelect`/`CoilMultiSelect` stay two widgets because their triggers differ |
| 2026-11-13 | `CoilCarouselDots.value` is an index | dots stand for slides, which the carousel indexes |
| 2026-11-13 | `CoilTable.onRowActivated` opens a row; `onChanged` selects | Enter and a tap open when a row has a destination, else they select |
| 2026-11-13 | User-visible strings are parameters with English defaults until coil has a localization hook | no hardcoded English in semantics |
| 2026-11-13 | Motion-layer decorations are immutable items (`CoilHighlight`, `CoilSelectionBlocks`, `CoilLayerPaint`); `CoilMotionLayer` owns the animation and diffs items in `didUpdateWidget`. Painters are internal | components describe what they want in `build` with no side effects, like `AnimatedContainer`; a rebuild never re-runs an animation |
