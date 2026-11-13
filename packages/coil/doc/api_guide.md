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
| Components: look and composition | `package:coil/<component>.dart` | the above, `package:coil/foundation.dart`, `package:coil/primitives.dart`, other components' **public** libraries |

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
| Popover vs sheet | `CoilPresentation { popover, sheet }` | — |
| Corner family | `CoilShape { rounded, pill, sharp }` | — |
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
| Per-instance motion | `motion: CoilMotion?` | see §6 |
| Per-instance style | `style: Coil<Name>Style?` | see §6 (M1) |
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
| travelling highlight, pills, merge/split selection | `CoilMotionLayer` with `CoilHoverRegion`, `CoilHighlightPainter`, `CoilSelectionPainter` |
| anchored popover | `CoilPopoverRoute` via `CoilAdaptivePopup` |
| sheet | `CoilSheetRoute` via `CoilAdaptivePopup` |
| popover or sheet? | `CoilAdaptivePopup.presentationOf` (the hybrid phone rule) |
| editable text | `CoilTextFieldCore` |
| enter/exit, cross-fades, size changes | `motor_widgets` (`MotionSwitcher`, `MotionTransition`, `MotionSize`). Until that package lands, leave `TODO(motor_widgets)` |

## 4. Enums over booleans

A boolean parameter is allowed only for a true yes/no state of the control
(`value` of a switch, `invalid`, `loading`, `selected`, `autofocus`). Anything
that picks one of several looks or behaviors is an enum, even when it has two
values today:

- `CoilTabs(labels: CoilTabLabels.selected)`, not `activeLabel: true`.
- `CoilButton(variant: .ghost)`, not `ghost: true`.
- `CoilPresentation.sheet`, not `useSheet: true`.

Two booleans that can contradict each other are a smell; see the open
question on `CoilCheckbox.indeterminate`.

## 5. Slots over flags

- A component that shows something optional takes a `Widget?` slot, not a
  `showX: bool`. `leading: null` means no leading slot.
- coil bundles no icons. Slots take any widget; the component styles them
  with `IconTheme` (size, color, `weight`) and `DefaultTextStyle`.
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
5. Per-component-type: reserved for `style:` classes in the theme (M1).
6. Per instance: the component's `style:` (M1) and `motion:` parameters.
7. High contrast (`MediaQuery.highContrastOf`): applied by `CoilTheme.of`.
8. Reduced motion (`MediaQuery.disableAnimationsOf`): applied **last** by
   `CoilTheme.motionOf`, on top of whatever 1–7 produced.

`motion:` takes a whole `CoilMotion`. Write it as a copy of the inherited
tokens when only one field changes:

```dart
CoilSwitch(
  value: on,
  onChanged: (v) => setState(() => on = v),
  motion: CoilTheme.of(context).motion.copyWith(standard: const CupertinoMotion(duration: Duration(milliseconds: 300))),
)
```

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
- `CoilActiveItemController` is the only coil controller in M0.
- `items`/`options` are used only for collections whose entries are data
  (`CoilSelect.options`, `CoilTabs.tabs`). Composition (`children`) is used
  when entries are arbitrary widgets.

## 8. Platform behavior

- Hover only from hover-capable pointers (`CoilInputModality.canHover`).
- Press shows on touch-down, clears on up/cancel/scroll, and stays visible at
  least `CoilMotion.minPressDuration` (90 ms) after a quick tap.
- The focus ring shows only after keyboard use (`CoilModality.keyboard`).
- Native first: iOS `SystemContextMenu` for text, the browser's menu on web,
  platform keyboards and autofill. Material/Cupertino selection handles and
  toolbars only inside `CoilTextFieldCore`.

## 9. Settled-choices log

| Date | Choice | Why |
|---|---|---|
| 2026-11-13 | Package `coil`, prefix `Coil` | PLAN §14 |
| 2026-11-13 | Names in §2 resolve research 02 vs 03: one motion class `CoilMotion`, `CoilTier` for pointer/touch, `CoilSize` for regular/compact, `CoilMetrics`, `CoilInputModality` | 02 and 03 each used two names for the same idea; the spikes added a third |
| 2026-11-13 | Tier names `pointer`/`touch`, not `desktop`/`touch` | an iPad with a trackpad is still `touch` tier; the name says what the sizes are designed for, not the device |
| 2026-11-13 | Springs only; no `FluidMotionDelta`, `FluidSpring`, `fromWeb`, no curves | PLAN §12; exits are tighter springs so a reversal keeps velocity |
| 2026-11-13 | Opacity/color use `fade`/`fadeExit`, which survive reduced motion | reduced motion is "fewer and gentler", not none |
| 2026-11-13 | Tier latches by platform; the pointer kind of each event decides hover/press | PLAN §3. The mobile spike's live input mode (metrics jumping when a mouse clicks on an iPad) is dropped |
| 2026-11-13 | One adaptive scope `CoilAdaptiveScope` for tier, size and presentation pins | the spikes had `FluidSizeScope` and `FluidAdaptiveScope` doing overlapping jobs |
| 2026-11-13 | Value controls are controlled; `onChanged` reports the new value; null `onChanged` disables | Flutter idiom; removes the mobile spike's `enabled` + callback duplication |
| 2026-11-13 | `CoilSelect<T>` and `CoilMultiSelect<T>` are two widgets | one `onChanged` name with one type per widget, instead of `onValuesChanged` |
| 2026-11-13 | Tabs: `value` (index) + `onChanged`, `labels: CoilTabLabels` | same idea, same name; enums over booleans |
| 2026-11-13 | `CoilButton.selected` (was `active`) | matches `WidgetState.selected` |
| 2026-11-13 | Collection items carry `label: String` plus optional `child` | typeahead and semantics need text |
| 2026-11-13 | `CoilTheme.override(transform:)` for subtree deltas | the transform runs on the parent's data, so root changes still flow through and nothing is snapshotted |
| 2026-11-13 | The brand color is `CoilColors.brand` (was `fluidAccent`) | `accent` already names FF's neutral `--accent` |

## 10. Open questions

1. `CoilCheckbox` has `value: bool` + `indeterminate: bool`, two booleans
   that can contradict. Options: keep (Flutter's `Checkbox` uses
   `bool? value` + `tristate`), or `value: CoilCheckState`. Undecided.
2. `style:` classes (per type and per instance): the shape (nullable fields
   + `merge`, `fallback(resolvedTokens)`) is agreed in research 03 §5.2 but
   not built. Do they land in M1 for all components at once, or per
   component?
3. Should tabs and segmented groups take generic values (`CoilTabs<T>`)
   instead of an index? The index matches Flutter's `TabController`, a
   generic matches `CoilSelect<T>`.
4. Per-component motion deltas (03 §5.2 `FluidSwitchMotion(thumb:)`) or only
   whole `CoilMotion` overrides? M0 has only the latter.
5. `CoilAdaptiveScope.presentation` pins every overlay below it. Is a
   per-kind pin (menus vs selects) needed?
