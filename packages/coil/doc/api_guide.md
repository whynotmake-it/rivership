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
| Primitives: interaction, focus, active item, motion layer, anchor, presence, sheet, drawer, screen radius, adaptive popup, text-field core | `package:coil/primitives.dart` | the above, foundation, other primitives, `motor_widgets`, `stupid_simple_sheet`; `scroll_drag_detector` only in `drawer.dart`, `corner_radius_plugin` only in `screen_radius.dart` |
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
- A third-party package enters through one primitive, so replacing it
  touches one file: `corner_radius_plugin` (the screen's corner radius) is
  imported only by `screen_radius.dart`, behind `CoilScreenRadius`, and
  `scroll_drag_detector` only by `drawer.dart`, behind `CoilDrawer`.
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
| Type | `CoilTypography` (roles per tier and size), `CoilTextTheme` (the roles as `TextStyle`s), `CoilTheme.textOf` | `FluidTypographyThemeData`, `FluidTypeRole` |
| Focus ring | `CoilFocusRingTheme` (width, gap, color; `extent` and `decorationAround` for a ring that travels between rows) | none |
| An app's icon set | `CoilIcons` (one `Widget?` per `CoilIconRole`: `check`, `dash`, `copy`, `failed`, `close`, `alert`, `chevronStart`, `chevronEnd`, `chevronDown`, `chevronUp`, `send`, `stop`) on `CoilThemeData.icons`; `CoilIcon(role)` shows the theme's or coil's drawn glyph | FF's `IconProvider` / `useIcons()` |
| An icon's presence while it animates | `CoilIconPresence` (`maybeOf`, `transition`), shown with `CoilIconSwitcher` | none |
| Lighting (flat → lit) | `CoilPlasticity(amount:)` (0 to 1; `.flat` is 0, the default, `.subtle` 0.5; `flattenAbove`) on `CoilThemeData.plasticity` and each control style's `plasticity`; resolved per `CoilReliefRole { raised, filled, quiet, recessed, field, track }` into a `CoilRelief` with `CoilTheme.reliefOf(context, role)` and painted by `CoilRelief.decorate(shapeDecoration, relief)` | none |

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
| What an item in a collection shows | `label: Widget` | usually a `Text`; the component styles it and screen readers read it |
| An item as plain text, for matching | `searchText: String?` | typeahead and filters match it, and a select announces it as its value; without it they skip the item |
| A name for screen readers | `semanticLabel: String?`, or a name ending in `Label` | only where the visible widget can't name the thing (an icon-only toggle, an announcement) |
| Text a component builds from data | a builder returning a `Widget`, with a `…Label` string function beside it if screen readers need it | `CoilCalendarLabels.monthTitle` / `.dayLabel`, `CoilDataTableLabels.count` |
| Leading / trailing slot | `leading`, `trailing` | any `Widget`, styled by `IconTheme` and `DefaultTextStyle`. Where the slot's place can change, `leadingPlacement` / `trailingPlacement` (`CoilInputSlotPlacement?`, null is `auto`) |
| Icon-only content | `icon` | named constructor `.icon(...)` where a widget can be icon-only |
| Drawn glyph replacement | `<glyph>Builder` or a `Widget?` slot for one instance; `CoilThemeData.icons` (a `CoilIcons` role) for the whole app | e.g. `CoilCheckbox.glyphBuilder`, `CoilSelect.checkmark`, `CoilIcons.check` |
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
| sheet | `CoilSheetRoute` (coil's surface, corners and scrim on `stupid_simple_sheet`'s plain `StupidSimpleSheetRoute`) with a `CoilSheetPanel`, via `CoilAdaptivePopup` or `CoilModalRoute` |
| a sheet's close button and its place (the header's corner per platform, or the end of a search line) | `CoilSheetPanel.close` (a `CoilSheetCloseButton` by default; `headerLayout: CoilSheetHeaderLayout`), `CoilSheetCloseSlot` at the end of a line that replaces the header |
| buttons that end a dialog or sheet | `CoilActionBar` (a trailing row, or on a phone a full-width stack with the primary on top), pinned in a sheet as `CoilSheetPanel.footer`. A footer that leads with a summary of what its one action confirms (the date picker's) puts the action in a `CoilActionBar` row after it instead of a stack (DESIGN.md §13.5) |
| modal route (dialog, settings, command menu, or a route-level drawer) | `CoilModalRoute`, or `CoilModalPage` in `Navigator.pages`, presented `centered`, as a `sheet` or as a start-edge `drawer` (`CoilModalPresentation`); content reads `CoilModalRoute.presentationOf`. A drawer that must stay a descendant of the page is `CoilDrawer` |
| side panel that stays a descendant (phone sidebar) | `CoilDrawer` (`reveal: .behind` or `.over`, `start`/`end` panels, nests) |
| the device screen's corner radius | `CoilScreenRadius` |
| popover or sheet? | `CoilAdaptivePopup.presentationOf` (the hybrid phone rule) |
| editable text | `CoilTextFieldCore` |
| a raised surface (fill, shadow, edge) and its level scope | `CoilSurface` |
| enter/exit of a popover | `CoilBlurFade` (via `CoilAdaptivePopup`) |
| haptic feedback | `CoilHaptics.play(context, event)` |
| a pile of cards that peeks folded and fans out into a list (folded peeks, fanned spacing by measured heights, anchoring, which card takes input, Tab order) | `CoilCardStack` with `CoilCardStackItem`s and a `CoilCardStackController` |
| copy to clipboard with feedback (copy glyph → check, 2 s hold, extend on repeat, announce) | `CoilCopyController` with `CoilCopyGlyph` (the icon) and `CoilCopySwitcher` (a label beside it) |
| an icon coil draws (a check, an ×, a chevron) | `CoilIcon(role)`, after the component's own slot: `slot ?? const CoilIcon(.close)`. A default that draws its own way (the copy feedback, send/stop) checks `CoilTheme.of(context).icons[role]` first; a bare `CoilDrawnGlyph` would skip an app's `CoilIcons` |
| an icon that appears, disappears or swaps | `CoilIconSwitcher` (a `MotionSwitcher` whose children get a `CoilIconPresence`), on the component's tokens; a default glyph that must look its own way reads `CoilIconPresence.maybeOf` itself |
| keyboard commands | `Shortcuts` mapping keys to intents, handled in `Actions`; never `Focus.onKeyEvent` or `CallbackShortcuts` (typeahead is the exception). A command an app may want to change gets a public `Coil…Intent` handled by `CoilDefaultAction` (`CoilDismissIntent` for Escape on any popup); the rest use private intents. Flutter's intents only where coil's action is the nearest (`ActivateIntent`), never `DismissIntent`, `ScrollIntent` or `DirectionalFocusIntent` (DESIGN.md §9.2.1) |
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
  Icons are widgets, never `IconData` (`test/architecture/widget_params_test.dart`).
- Glyphs a component draws itself are icons with a role: the component
  shows `CoilIcon(role)` after its slot, so the order is the slot, then the
  theme's `CoilIcons` entry, then coil's `CoilDrawnGlyph`. Roles are named
  for what they mean (`close`, `failed`, `chevronEnd`), not their shape
  (`cross`); a new glyph gets a role, a `CoilIcons` field and a row in
  doc/icons.md. A place without a slot still reaches the theme's icon.
- Lay an icon out like `Icon` does: give it `IconTheme.size` and let it
  sit in its box. Where a component's box is bigger than the icon, set
  `IconTheme.size` to what coil's glyph fills, so an app's `Icon` lands on
  the same rect.
- An icon that animates in, out or into another gets a
  `CoilIconPresence` (via `CoilIconSwitcher`): 0 to 1, clamped, on the
  component's tokens, instant under reduced motion. An icon that reads it
  animates itself; the rest get the fade-and-scale fallback. coil's own
  defaults read it too, so they use the API apps use. A spring's bounce
  goes on a container outside the icon, never into the presence.
- The spinner, the radio dot and step dots aren't roles: they are
  indicators, not icons.
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
   onto an existing entry), springs included (the style's `motions`).
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
- `merge(other)`: `other`'s non-null fields win (text styles merge;
  `WidgetStateProperty` fields merge per state with
  `CoilComponentStyle.mergeStates`, so an override naming only `hovered`
  keeps the lower layer's rest color);
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
- Theme-level overrides live in the component's style, next to the rest of
  its look, under the same keys:
  `CoilSwitchStyle(motions: {CoilSwitchTrack.thumb: …})`, set with
  `withComponentStyle` or per instance with `style:`. `merge` combines the
  maps key by key, the upper style's entries winning.
- Resolution for one track, through `CoilTheme.trackMotionOf`: the
  instance's `motions` entry, else the resolved style's `motions` entry
  (the instance's `style:` merged over the theme's), else the token the component maps the track to (`thumb` → `standard`,
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
| `standard` / `standardExit` | indicators that must land: tab pill, switch thumb, merge/split, popovers; the drawer, which a finger drags and which has to land as fast |
| `gentle` / `gentleExit` | large surfaces: dialogs, panels (the sidebar folding); sheets use `gentle` both ways |
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
| 2026-11-14 | `expectCoilPattern` and `CoilPattern` are public in `package:coil_cli/testing.dart`; coil_cli is a dev dependency that also holds the eject tools | apps check ejected copies with it, and coil keeps `flutter_test` out of its dependencies; supersedes the 2026-11-13 "internal" entry |
| 2026-11-13 | Every component has a style class (§6) | landed together before the waves |
| 2026-11-13 | Tabs and groups are generic in `T`; choices are `CoilOption<T>` (§7) | indexes leak layout into app state |
| 2026-11-16 | Theme-level springs live in each component's style as a typed `motions` map, not in one flat theme map | springs are part of a component's look, and typed keys only accept that component's tracks; supersedes the 2026-11-13 flat-map entry |
| 2026-11-13 | No per-kind presentation pin | YAGNI; a component's `presentation:` covers the exceptions |
| 2026-11-13 | `CoilPopupController`, like `MenuController`; `open()` resolves once with a `CoilPopupCloseReason` (§7) | overlay acceptance tests |
| 2026-11-13 | `CoilButton.selected` (was `active`) | matches `WidgetState.selected` |
| 2026-11-13 | Collection items carry `label: String` plus optional `child` (replaced 2026-11-14) | typeahead and semantics need text |
| 2026-11-13 | `CoilTheme.override(transform:)` for subtree changes | root changes still flow through |
| 2026-11-13 | The brand color is `CoilColors.brand` (was `fluidAccent`) | `accent` already names FF's neutral `--accent` |
| 2026-11-13 | Groups take `options` (data entries) and `values`; `CoilRadioGroup` takes `value`. All three take `semanticLabel` | data entries use `options`; sets use `values` |
| 2026-11-13 | `motion:` sets the tokens; `motions:` overrides single tracks (§6) | PLAN §15 |
| 2026-11-13 | `CoilBlurFade` is the overlay enter/exit, also as a `MotionSwitcher` transition | `motor_widgets` holds only Flutter equivalents |
| 2026-11-13 | A text field shows its focus border however it was focused | as `:focus-visible` does for inputs; every other control shows the ring only after keyboard use |
| 2026-11-13 | `CoilSlider` follows Flutter's `Slider` (`value`, `onChanged`, `min`, `max`, `divisions`, `onChangeStart`, `onChangeEnd`) with two differences: `label` is the row's `Widget`, not the value-indicator string, and the shown value is a widget from `valueBuilder`, with `semanticFormatter` for screen readers (see 2026-11-14). The pill is a `variant`, not a size | a Flutter user would guess `label` is a string; size must not change anatomy |
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
| 2026-11-14 | `CoilRangeSlider` is its own widget taking `values: CoilRangeValues(start, end)`, like Flutter's `RangeSlider` (whose `RangeValues` lives in Material). It shares `CoilSliderTrack` and the pill look | a nullable second value would give one widget two value types; a range on the row puts handle lines in the text |
| 2026-11-14 | Sliders take `steps: List<double>?` next to `divisions`, never both; `valueDisplay: CoilSliderValueDisplay { text, editable, tooltip }` | a list of allowed values isn't a count; where the value shows is one choice of three, so an enum, not booleans |
| 2026-11-14 | Text a component styles with `DefaultTextStyle` is a `Widget` parameter, not a `String` (and icons are widgets, not `IconData`). The slider shows its value through `valueBuilder: (context, value) => Widget`; `semanticFormatter` gives screen readers a string, and the value field's text goes through `editFormatter` / `editParser` | user, 2026-11-14: string params are an antipattern; a field and semantics genuinely need strings |
| 2026-11-14 | Every visible text and icon is a `Widget`. Entries carry `label: Widget`, plus `searchText: String?` where typeahead or a filter matches them and `semanticLabel: String?` where the widget can't name them; the `child` override is gone. Strings a component shows from data become builders returning widgets. A string that both showed and announced splits into a widget and a `…Label` string. `test/architecture/widget_params_test.dart` fails on a new public `String` or `IconData` field unless its name says it's for screen readers (`…Label`) or matching (`searchText`), or it's on the test's allowlist with a reason | user, 2026-11-14: string and `IconData` params are an antipattern; a matched or announced string can't be a widget, so it gets a name that says so |
| 2026-11-14 | Every modal is reachable as a route: `CoilModalRoute<T>` (one adaptive route; null `presentation` is a sheet on a phone, centered elsewhere) and `CoilModalPage<T>`. The `showCoil…` functions only push it. Dialog, settings dialog and command menu have no route class of their own: their content (`CoilDialog`, `CoilSettingsDialog`, `CoilCommandMenu`) goes in a `CoilModalRoute`, and `CoilDialogKind.presentation` maps a kind to its presentation | the presentation decides the route's class (a sheet is a `stupid_simple_sheet` route), so one factory route picks it; per-component route types would each need a private class per presentation and add API without behavior |
| 2026-11-17 | (Superseded below by coil's own sheet on the plain route.) Sheets are `stupid_simple_sheet`'s `StupidSimpleGlassSheetRoute`, used as it is: `CoilSheetRoute(context:, child:)` reads coil's motion (`gentle`, both ways), surface and corner from `context` and keeps the glass sheet's own scrim (black 15 % over the blur); `CoilSheetPanel` keeps only the grabber, title, scroll-edge hairline and safe area (superseded in part by the 2026-11-17 `CoilActionBar` row: it also takes a pinned `footer`). Gaps go upstream (short glass sheets) instead of into coil. No separate exit motion: the glass sheet uses one motion in and out, and coil doesn't add one | owner: "for sheets, let's just use GlassSheet"; one sheet look and its stacking, blur and drag for free. Owner, 2026-11-17: no `exitMotion` upstream, and the 40 % / 50 % scrim was too heavy |
| 2026-11-17 | Every copy affordance runs on `CoilCopyController` (primitive): a copy while the result shows only restarts the 2 s hold, and a copy while it leaves turns it around; `CoilCopySwitcher` keys its content by status alone. Without an icon, coil draws a copy glyph | owner review: a copy button must always show, and spam-clicking must not replay the animation |
| 2026-11-17 | One `CoilDrawer` primitive with `reveal: CoilDrawerReveal { behind, over }`, `start` and `end` panels, `open: CoilDrawerEdge?` + `onOpenChanged`; the old overlay drawer is its `over` mode, rendered in place instead of through an `OverlayPortal` | one drawer behavior (focus, back, Escape, drag, springs) for both looks; the scaffold picks `behind` on touch and `over` on the pointer tier. In place keeps the page and panel in one layout, which the reveal needs |
| 2026-11-17 | Two sidebars are two nested scaffolds; their drawers coordinate (drag hand-off to the enclosing drawer, one open at a time) and `CoilSidebarTrigger.side` picks the scaffold | a second sidebar slot would double the scaffold's controller, rail and width API for a layout composition already gives |
| 2026-11-17 | The drawer opens by dragging the page anywhere through `scroll_drag_detector` (`boundaryStart` from rest, `scrollFirst` while open); on iOS/macOS a start-side drawer on a poppable route defers to the back swipe | supersedes DESIGN.md's "no edge-swipe drawers": a scroll-aware drag doesn't fight carousels, and the back-swipe rule keeps the iOS conflict out. An edge-strip exclusion can't be expressed: the drawer's recognizer would still win the arena |
| 2026-11-17 | `corner_radius_plugin` (MIT; Android 12+ `RoundedCorner`, iOS 26 `UICornerConfiguration`, older iOS via BezelKit) behind `CoilScreenRadius`, asked once, null on web, desktop and in tests | the owner reported its iOS bug (issue #1), and it is the maintained option with both platforms; callers fall back to their own radius |
| 2026-11-17 | No coil `ScrollBehavior`. Scrolling components inherit the app's ambient behavior (physics, overscroll, drag devices); `CoilScrollbar` draws coil's bar and only sets `copyWith(scrollbars: false)` on its child | scrolling must feel native on every platform, and an app that sets its own behavior should get it inside coil too |
| 2026-11-17 | `CoilBlurFade.defaultBlur` is 1.5 (was 4); callers that want less pass a fraction of it, never a literal | sigma 4 read as a smear on text; one constant keeps every blur-fade in proportion |
| 2026-11-17 | Keys are `Shortcuts` + `Actions` with intents. Public `Coil…Intent`s (`CoilDismissIntent`, `CoilSliderStepIntent`, `CoilSliderLimitIntent`) for commands an app may replace, handled by `CoilDefaultAction`; private intents for the rest. Not Flutter's `DismissIntent`/`ScrollIntent`/`DirectionalFocusIntent`, and not `Action.overridable` | action lookup starts at the focused widget, and text fields, routes and `WidgetsApp` already hold actions for Flutter's intents; `Action.overridable` takes the nearest action above as the override, which for a submenu is its parent menu's |
| 2026-11-17 | Plasticity: one intensity vector `CoilPlasticity` resolved per role and brightness into a `CoilRelief` (gradient edge, top/bottom rims, sheen, outside-only drop shadows). Flat resolves to null and components keep their decorations untouched | one setting has to read right on white, black, blue and dark fills; glass would be a further preset above `tactile` with its own renderer (superseded 2026-11-17: one `amount`, see below) |
| 2026-11-17 | `CoilPlasticity.subtle` lights what you press (buttons, thumbs, trigger, selected pills) at about 2/3 of opencode's strength (raised to 0.78 and 0.8 below), with half-depth hover/press; wells get a hairline, fields barely any, tracks, quiet buttons and containers none. Per-role restraint is data (`roles`), not new presets | owner review: the first A was too strong and too wide; the slider read noisy (superseded 2026-11-17: one `amount`, see below) |
| 2026-11-17 | Controls on a surface above the page aren't lit: `CoilSurface` (and `.scope`) places a `CoilPlasticityScope(elevated: level > plasticity.flattenAbove)` (`CoilPlasticity.flattenAbove`, 1 by default, read from the theme's plasticity as set, `CoilTheme.plasticityOf`; owner: the cutoff is configurable), and `CoilTheme.of` reads a flat plasticity inside it. A component style's `plasticity`, or `CoilPlasticityScope(elevated: false)`, lights them anyway | owner review: a lit button on a card or in a popover competes with the surface |
| 2026-11-17 | Selection indicators (the tabs pill, toggle-group segments, merged selection blocks) are never lit; `subtle` lights raised controls at 0.78 and filled at 0.8 | owner review: an indicator marks the current item, it isn't pressed; pressables a hair stronger |
| 2026-11-17 | Card piles (sidebar callouts, queued messages) share one primitive, `CoilCardStack`: folded peeks are measured at the cards' far edges and fanned-out cards stack by measured height with the tier's gap; anchor edge, when it fans (`CoilCardStackExpand { auto, always, never }`; the controller's `pinned` is the tap's part of `auto`, cleared under `never` or below two cards, so there is no `holdExpanded` boolean to contradict it), how a tap-pinned pile folds (`CoilCardStackFold`), peek and scale are configuration; motion is `motion:` plus `motions:` keyed by `CoilCardStackTrack`. Cards read the pile through static lookups (`CoilCardStack.maybeExpandedOf`, `.maybeLeaveOf`, `.pileExtentOf`), not public scope widgets. A dismissible `CoilCard` in a pile fades in place (`CoilCardStack.maybeLeaveOf`) instead of collapsing | owner review: mixed card heights spaced unevenly, and two layouts duplicated the same rules |
| 2026-11-17 | Dialog and sheet buttons go through one primitive, `CoilActionBar(actions:, layout: CoilActionBarLayout?)`, null picking `CoilActionBar.layoutOf(context)`: `row` (trailing, at the buttons' width) on the pointer tier and in wide windows, `stack` (full width, primary on top, Cancel at the bottom) in a sheet or on the touch tier under 600, centered confirmations included. Never a two-up row. A sheet pins it as `CoilSheetPanel.footer`. `CoilInteraction`'s minimum hit target now lays the visual out with the parent's constraints | owner, on stacked buttons centered at their own width in phone sheets: "That's very wrong". One shape whatever the label length, locale or text size, in the order both platforms stack; the old `ConstrainedBox` + `Center` loosened a tight width, so no parent could stretch a touch-tier button |
| 2026-11-17 | `CoilDrawer.motion` is a `CoilMotion?` (was raw `motion`/`exitMotion` springs) and slides on `standard` / `standardExit`, not `gentle`. No `CoilDrawerTrack`: the drawer animates one value, so the open and close tokens are all it needs; the sidebar's `drawer` track reaches it as a copy of the tokens | raw springs skipped reduced motion. The drawer follows a finger and releases into the spring, so it lands like an indicator; DESIGN.md already put it on `standard` |
| 2026-11-17 | `CoilDrawer`'s look is one immutable `CoilDrawerLook` (`look:`, null is `CoilDrawerLook.fallback(theme, reveal:)`: corners, fallback corners, scrim, shadows, content and panel fills) and its slide choreography another, `CoilDrawerTransition` (`scale`, `panelScale`, `panelOpacity`), instead of nine loose parameters; its numbers are named (`CoilDrawer.maxWidth`, `.widthFraction`, `.flingVelocity`, `CoilDrawerLook.behindScrimLight`/`Dark`, `.edgeShadowLevel`, `.phoneCornerRadii`). `CoilSidebarStyle` keeps the look fields (`drawerCornerRadius`, `drawerFallbackCornerRadius`, `drawerScrimColor`, `drawerShadows`) with `fallback` computing them, except `drawerScrimColor`, which stays null for the reveal's scrim; the transition moved off the style to `CoilSidebarScaffold.drawerTransition` | §6: `fallback` computes every field and styles hold look only. How the page and panel move is choreography, not look; the scrim depends on the reveal, an adaptive choice the style can't see |
| 2026-11-17 | Relief is looked up with `CoilTheme.reliefOf(context, role, override:)`, not a method on `CoilThemeData`. A `floating` shape (a surface's own edge) reads the plasticity as set, not the flat one inside an elevated scope | lookups are static on `CoilTheme` (§2); a popover's lit edge must not depend on whether it was opened from a card (the `floating` part is superseded: containers are never lit, see below) |
| 2026-11-17 | Plasticity is one `CoilPlasticity(amount:)`, 0 to 1, over subtle's character: 0 flat (the default, paints nothing), 0.5 `subtle` as tuned, 1 a slightly brighter top rim and edge and a slightly stronger sheen; in between interpolates. `soft`, `tactile`, `scale`, the per-ingredient intensities, `roles`, `response` and `edgeWidth` are gone (the recipe is private), `flattenAbove` stays. Containers are never lit: `CoilReliefRole.floating` and `CoilCardStyle.plasticity` are gone. The raised and filled roles are balanced so primary, secondary and destructive buttons read equally lit | owner: "subtle is the only acceptable one"; one knob with checkpoints at 0, 0.5 and 1. The secondary button read more 3D than primary and destructive, so the tints' bottom edge and rim came down a little and the primary's rim and sheen up; floating lighting only existed for `soft` and `tactile` |
| 2026-11-17 | Sheets are coil's own: `CoilSheetRoute` extends `stupid_simple_sheet`'s plain `StupidSimpleSheetRoute` (drag, scroll handoff, keyboard inset, its stacking) and paints a `CoilSurface` at the popover level in a `RoundedSuperellipseBorder` with the glass sheet's 36 top corners (`CoilSheetRoute.glassRadius`, scaled by the shape family), clipping the content. The barrier is `CoilColors.scrim`, with no blur. The sheet hugs its content up to the top safe area or 5 % of the height. `CoilSheetRoute.shape` is a `RoundedSuperellipseBorder`; the glass route's options (`blurBehindBarrier` and the rest) are gone. Scrollables that take their own behavior use `CoilSheetRoute.scrollBehaviorOf`. No changes to `stupid_simple_sheet` | owner: "Let's just build a custom CoilSheet, using the same radius as GlassSheet with superellipse. Dim the background with our scrim, but don't blur it. That sheet should size to content by default. [...] No changes to SSS." The glass sheet always grew to the full height, and one scrim for every modal keeps them alike |
| 2026-11-17 | Every sheet shows a close button: `CoilSheetPanel.close` is a `Widget?` slot defaulting to `CoilSheetCloseButton()` (pops the route like a dismissal; replace it, or pass null for none), not a `showClose` flag. Its side is `headerLayout: CoilSheetHeaderLayout { centered, start }`, null following the platform (`centered`, close leading, on iOS and macOS; `start`, title leading and close trailing, elsewhere). The header is one 44 line through the top corner's center, and the button sits on that center, concentric with the corner. Search sheets put it at the end of the search line with `CoilSheetCloseSlot`; dialogs and settings dialogs shown as sheets use the sheet's button (wired to their `onClose`) instead of their own | owner: "Our sheet header doesn't seem aligned properly [...] we're missing a close button as a signifier. Make sure the close button is in the correct place per platform." Apple's HIG puts Cancel/Close on a sheet's leading edge with a centered title; Material puts a sheet's close affordance at the end of the header with a leading headline |
| 2026-11-18 | `CoilDatePicker` keeps a draft and reports only a confirmed date: a popover picking a date alone confirms on the tap; a popover with time and every sheet confirm with Done (`CoilCalendarLabels.confirm`, the sheet's pinned `footer`); everything else cancels. Enter confirms through `CoilCalendar.onSubmitted` (named like `TextField.onSubmitted`), so Space can pick without confirming | owner: "The date picker doesn't have a confirm action. Bad in the sheet case." iOS's compact popover, web libraries (shadcn/Radix, React Aria, MUI desktop) and FF commit a single date on the tap; Material's modal pickers and MUI's mobile and desktop date-time pickers confirm with OK |
| 2026-11-18 | The calendar's month view and confirm label are new `CoilCalendarLabels` entries (`monthName`/`year` widgets, `monthLabel`/`chooseMonthLabel` strings, `confirm` widget), not new parameters on the picker | one place for a calendar's localizable text, as §2 asks (`monthTitle`/`dayLabel` already live there) |
| 2026-11-19 | The calendar's month view is a horizontal pager, one year per page (a 3 × 4 grid under the year), in exactly the days' space, with the same zoom. The arrows stay in it and turn a year; the title names the keyboard's month in the year more than half in view, and the title or Escape zooms into that month | owner: "the month view should page horizontally, like the days", so a vertical drag moves a sheet again. A mouse can't swipe a pager (§ Calendar, Motion), so without the arrows a pointer user would be stuck in one year; with a page per year the title's year reads like the days' title, and zooming into the month it names is how iOS's inline picker's title behaves |
| 2026-11-19 | (Superseded below: no chip; the date picker's footer names the draft.) The selection shows as a chip in the calendar's header, beside the arrows, only while it's out of view (its month in the days, its year in the month view): a compact secondary `CoilButton` with the short date (`CoilCalendarLabels.selection`, "Nov 14"; `selectionLabel` for screen readers). It blur-fades in on `fade` while its room springs open on `standard`; a tap turns the days back to its month or zooms the months into it. It follows the calendar's `selected`, so a date picker's chip shows the draft | owner: "If you zoom out and scroll to 1990, you can't tell where the selected date is or get back to it." Calendar apps keep their jump-back control (Today) in a bar outside the grid (Google Calendar's top bar, iOS Calendar's toolbar); the header is that bar here, and on the touch tier the chip is a full touch target. Shown only when needed, since the filled cell already marks it otherwise and the popover's header has little room; the tinted fill tells it from the ghost arrows |
| 2026-11-18 | The drawer revealed from behind veils the page by brightness: `CoilDrawerLook.behindScrim(colors)` is the top surface (white) at `behindVeilAlpha` 35 % in light and `behindScrimDark` (black 15 %) in dark; `behindScrimLight` is gone. Over the page it stays the theme's `scrim` | owner review: the page swiped aside should get lighter in light mode, receding into haze; in dark, lightening reads as a highlight (the page looks raised), so it dims there. Tuned by eye on iPhone 16 Pro / Pixel 9 renders: 25 % barely shows, 45 % washes the page out |
| 2026-11-18 | The drawer's handoff modes follow the drag, as `stupid_simple_sheet`'s do its extent: at rest `boundaryStart` (closed) or `scrollFirst` (open) for the directions it moves in; once a drag that came out of a scrollable moves it away from where it began, `dragFirst` both ways (for nested drawers, the inner ones' routing too) until it is back there | owner review: moving back while opening from a carousel handed the drag to the carousel mid-reveal (jank). A sheet dragged down keeps the drag back up until it is at the top; the drawer does the same toward where the drag found it. Drags from outside any scrollable don't change the modes, since swapping the scroll behavior then would rebuild every scrollable for nothing |
| 2026-11-18 | A text field places its slots by measuring them in the layout pass that lays out the text (a slotted `RenderBox`, not a post-frame measure): a slot that fits the line is inline, a taller one (a button) goes into the padding, centered and evenly inset with a concentric corner, and the field grows only when it doesn't fit. Overridable per slot with `leadingPlacement` / `trailingPlacement: CoilInputSlotPlacement { auto, inline, inset }`. A `CoilButton` reads `CoilInputSlotScope` (primitives) for its default size, its corner and dropping its touch hit padding; the minimum inset is `CoilInputStyle.slotInset` | owner: a trailing button made the field larger ("the password field looks weird with the show button"); "only if that measure isn't a frame late" |
| 2026-11-19 | A sheet's surface runs a window's height past its bottom edge, so an upward overdrag shows the sheet's fill, not the page. `_SheetSurface` extends coil's own `CoilSurface` (fill, outline and dark-mode edge together) with `motor_widgets`' `PaddingExtended`, the mechanism `stupid_simple_sheet`'s `SheetBackground` uses; it doesn't use `SheetBackground`. The content keeps the sheet's size and is laid out as before | owner: coil's sheets didn't extend past the bottom of the screen; then "do not use `SheetBackground`. Keep coil's own surface primitives". `stupid_simple_sheet` passes no overdrag or extension value down (`SheetBackground` extends by a fixed window height), and `SheetBackground` paints only a fill, so wrapping `CoilSurface` in it would bury the edge or clip the outline |
| 2026-11-19 | The calendar's month view names its year once, in the title ("2020 ⌃"), not in a heading over the months: zooming out, the month title's width springs to the year's on `standard` with the year held at its end, while the month blur-fades out past the start. The months take the heading's room. The keyboard's month, where the title goes back to, gets the `active` wash while it isn't the selected one. `CoilCalendarLabels.year` is that title, and `yearLabel` / `showDaysLabel` ("Back to the days of April 2020") name it for screen readers | owner: "the year is shown twice". With the month gone from the title, the wash keeps the way back visible, as the month in the title did. The transition reads the month title as ending in its year, as the English default does; a localized title that leads with its year overlaps the two for the zoom's few frames, which a later `yearFirst` label could fix if a locale needs it |
| 2026-11-19 | No selection chip in the calendar's header (supersedes the 2026-11-19 chip entry): a date picker's footer names the draft instead, wherever it has a footer with Done (every sheet; a popover that picks a time), with the draft on the leading side (`CoilCalendarLabels.summary`, "Fri, Nov 22, 2019", with the time when it picks one; `summaryLabel`, "Selected: Friday, November 22, 2019", for screen readers; nothing before a pick) and Done on the trailing side at its own width, not full width. A date-only popover stays footer-less. `CoilCalendarLabels.selection` / `selectionLabel` are gone. The summary isn't a button, and the layout is the date picker's own, not a `CoilActionBar` option, with Done in a `CoilActionBar` row | owner: the chip "reads like a second title"; of five rendered directions, the owner chose the footer. It sits beside the action it describes, so it reads as "this is what Done confirms" rather than a heading, and the footer is already there. A summary-plus-action row is one layout so far; it moves into `CoilActionBar` once a second component needs it |
| 2026-11-19 | A calendar's edges are its days' edges: the title's text and the arrows' glyphs line up with them (ghost padding hangs outside), and a date picker puts its time band and footer on them, in a sheet on the sheet's text inset. The date picker's popover hugs the calendar (`CoilAdaptivePopup.minWidth: 0`) rather than the field's width. Days grow up to 30 % in a wide space | owner review: the popover centered the calendar in a field-wide box and nothing in the sheet shared an edge ("nothing is aligned") |
| 2026-11-19 | A date picker's popover applies each pick at once (`onChanged` per pick), with or without time; closing it is done, with no Done and no Cancel. Only the sheet keeps a draft and Done (supersedes the 2026-11-18 confirm entry for popovers) | owner: "on desktop not to have the done button, but instead just update the label"; iOS's compact picker, macOS and MUI's desktop pickers commit live, while the confirm camp is mostly modal (Material) or Ant, Mantine and Windows' time flyout |
| 2026-11-19 | An app's icon set is a role map in the theme, like Fluid Functionalism's `IconProvider`: `CoilThemeData.icons` is a `CoilIcons` with one `Widget?` per role coil draws (`CoilIconRole`, named for meaning: `close` and `failed` are both an ×), `merge`d so a partial set replaces only what it names, and every drawn glyph goes through `CoilIcon(role)`, slot first. Icons are plain widgets styled by `IconTheme`, not `IconData` or a builder. Animation goes through an inherited widget, not a wrapper: `CoilIconPresence` hands the icon a clamped 0–1 `Animation` on coil's tokens (instant under reduced motion); reading it claims it, and an icon that doesn't gets a fade and a scale from 0.8 at paint time. A swap is two presences crossing; coil's own tick, copy feedback and send/stop read the presence and keep their look. No morph or linear-progress contract; the spinner isn't a role | owner: apps swap coil's icons app-wide, the slotless places (calendar arrows, the sheet's close) were the gap; an inherited presence lets a custom set bring its own animations (a Lottie, a painter) while plain icons still animate, without a per-frame rebuild |
| 2026-11-19 | Every focus ring sits 2 px outside its control, concentric at the control's radius + 2 (DESIGN.md §5, §8.1, §13.4): `CoilFocusRingTheme.offset` defaults to 2 (was 0, a ring hugging the edge), and the rings that travel between rows (choice and toggle groups, menus, selects, tabs, accordions, questions, sidebar menus, calendar days and months) use the same geometry through `CoilFocusRingTheme.decorationAround` on the row grown by `extent`, instead of their own `1 + width` inflation at `CoilRadii.focusRing`. Component ring offsets (accordion, thinking steps, breadcrumb, carousel dots) default to the theme's, and the switch, slider and queued card drop their own 2. Parents that clip keep `extent` clear or clip only their scrolling sides | owner's decision: where the code and DESIGN.md disagreed, the spec wins, so every component draws the ring the same way. A choice card's ring follows the rule too; rings inside parents that can't make room (ScrollArea, table cells, a card's stretched action) stay inset |
| 2026-11-19 | Button labels are the body role at the theme's emphasis weight (`CoilTextTheme.emphasis`, wght 550 in the presets) in `CoilButtonStyle.fallback`, not plain body | owner's decision: DESIGN.md's "body semibold" wins over the code; a style's `textStyle` still overrides it |
| 2026-11-19 | A badge's corners are `shape: CoilBadgeShape { item, pill }` (default `item`, the theme's item radius; `pill` full under any shape family), an enum per §4, not a `pill: bool`; `pill` wins over a style's `radius`. A ghost badge keeps the badge's minimum height (24, compact 20) | owner's decision: DESIGN.md's "`pill` → full" becomes an option a badge can pick, and the ghost lines up with the other variants in a row |
| 2026-11-19 | `CoilToggleGroup`'s row is a 1 px `border` hairline with `CoilMetrics.segmentPadding` around its segments (`CoilToggleGroupStyle.border`, `padding`); the segments keep the item radius and the row's corner is `CoilRadii.concentric` with them | owner's decision: DESIGN.md's "segmented row with `segmentPadding`" wins; the token existed but nothing used it. A hairline rather than a tinted track keeps the `active` selection blocks readable |
| 2026-11-19 | A horizontal field's label and control sit `CoilMetrics.gap` apart (`CoilFieldStyle.besideGap` defaults to it: 8 pointer, 12 touch), not a fixed 12 | owner's decision: DESIGN.md's `gap` wins, so the pointer tier tightens to its own rhythm |
| 2026-11-19 | The command menu's search field is the subtitle role on a 48 (pointer) / 52 (touch) line, set through `CoilMenuSearch.textStyle` / `minHeight` rather than a command-menu-only field; the dialog caps at `min(440, 76 %)` of the window, search and footer included, replacing the list's 360 cap (`maxListHeight` removed); a footer of key hints (`CoilCommandMenuFooter`, a `footer:` `Widget?` slot defaulting to it, hints as `CoilCommandMenuHint` data) closes the dialog. The width `min(560, window − 32)`, the 20 % placement and the phone's sheet stay as the code had them, and DESIGN.md now says so | owner's decision: DESIGN.md wins on the field, height and footer; the code wins on width, placement and phone presentation. The footer is a slot (§5), so an app can localize, replace or drop it; it follows Fluid Functionalism's CommandMenuFooter (a label then its caps), without its row-dependent Enter label |
| 2026-11-19 | A switch's label stays muted while off on every tier, touch included; DESIGN.md changes, not the code | owner's decision: the label carries the switch's state, so it isn't the pointer-only "the pointer is here" fade that touch rows drop |
| 2026-11-19 | A dropdown's empty state keeps `popupInset + itemPaddingX` padding (12 pointer, 16 touch), not DESIGN.md's 24; DESIGN.md changes, not the code | owner's decision: the message starts on the rows' (and the search field's) text edge |
