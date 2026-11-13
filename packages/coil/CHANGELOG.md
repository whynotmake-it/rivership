## 0.0.1-dev.0

Milestone M0, unreleased.

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
- Test harness: golden matrix, pattern checker, ink centering, IME tests,
  import rules, runtime motion.
