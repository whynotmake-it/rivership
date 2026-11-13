## 0.0.1-dev.0

Milestone M0, unreleased.

- Breaking: `CoilHoverRegion` only tracks which item is lit. Paint the
  default highlight with `CoilHoverHighlight`, or read
  `CoilHoverRegion.maybeOf` and drive your own painters. `background`,
  `foreground`, `highlight`, `highlightColor`, `highlightRadius` and
  `onStateChanged` are removed.
- Breaking: metrics and corner radii are theme data:
  `CoilThemeData.metrics` (a `CoilMetricsTable`) and `CoilShape`, now a
  class. The static `CoilMetrics.resolve` is removed; read sizes with
  `CoilTheme.metricsOf(context, tier:, size:)`.
- Breaking: haptics are theme data: `CoilThemeData.haptics`, played with
  `CoilHaptics.play(context, event)`. `CoilHaptics` moved to
  `foundation.dart`.
- Breaking: popovers are `CoilPopover`, an `OverlayPortal` descendant of
  its owner, instead of `CoilPopoverRoute`. `CoilAdaptivePopup` is a widget
  around the anchor, driven by a `CoilPopupController`; its `traits` is a
  getter read when it opens. `CoilSpringRoute` is removed.
- Breaking: `CoilThemeData.copyWith(tier: null)` now clears the tier.

- Foundation: `CoilThemeData`/`CoilTheme` with subtree overrides, high
  contrast and reduced motion applied last; `CoilColors`; spring-only
  `CoilMotion`; `CoilTier` × `CoilSize` → `CoilMetrics`; `CoilTypography`
  with bundled Inter; `CoilInputModality`; `CoilAdaptiveScope`.
- Primitives: `CoilInteraction` (hover, press with a minimum visibility,
  focus-visible), focus ring, roving focus, typeahead, active item, the
  motion layer with the travelling highlight and merge/split selection,
  spring-driven routes with blur-fade, popover, sheet, the adaptive popup
  with the hybrid phone rule, and the text-field core on `EditableText`.
- Components on those layers: `CoilButton`, `CoilCheckbox`, `CoilSwitch`,
  `CoilTabs`, `CoilInput`, `CoilCheckboxGroup`, `CoilToggleGroup`,
  `CoilSelect`, `CoilMultiSelect`.
- Text inputs: `CoilInput.multiline` (3 to 10 lines, then scrolls),
  `CoilInputGroup` (fields share one hover), `CoilInputCopy` (copy with
  inline "Copied" on every platform), and `CoilField` with `CoilFieldSet`,
  `CoilFieldGroup` and `CoilFieldSeparator` (label, description, error and
  required marker, read with the control by screen readers).
- Components: `CoilBadge`, `CoilSkeleton` (with `CoilSkeletonText` and
  `CoilSkeletonRegion`), `CoilRadioGroup`.
- `CoilButton` swaps its spinner in with the blur-fade and takes `motions:`
  (`CoilButtonTrack`). `CoilSwitchTrack` gains `hover` and `label`.
  Checkbox, checkbox group, radio group and toggle group have tracks too.
- `CoilCheckboxIndicator` and `CoilRadioIndicator` draw the box and circle
  without interaction, for rows that are the tap target.
- Checkbox and toggle groups: arrow keys, a travelling focus ring and a
  press fill on touch. Shared by the three groups: `CoilChoiceGroup`,
  `CoilChoiceItem`, `CoilChoiceRow`; `CoilRovingFocus` gains `tabStops` and
  `onMoved`.
- Breaking: `package:coil/selection_groups.dart` is now
  `checkbox_group.dart` and `toggle_group.dart`. `CoilTapTargetSize` is
  removed.
- `CoilSlider`: one value, as a scrubber or pips row or a pill. Keyboard and
  screen-reader support. Range, step lists and click-to-edit come later.
- `CoilTabs` scrolls when the tabs don't fit. Edges fade, and the selected
  or focused tab scrolls into view.
- `CoilSurface`: a raised surface that reads the level it sits on, paints
  the fill, shadow and edge for its own level, and passes that level down.
  Shadow blur now matches the CSS recipes, and dark surfaces get the 1 px
  top highlight.
- Test harness: golden matrix, pattern checker, ink centering, IME tests,
  import rules, runtime motion.
