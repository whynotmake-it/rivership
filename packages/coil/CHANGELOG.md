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
- `CoilSlider`: one value, with scrubber and pips rows, a compact pill,
  hover preview, a value bubble and full keyboard and screen reader
  support. Range, step lists and click-to-edit come later.
- `CoilTabs` scrolls when the tabs don't fit: 24 px edge fades, and the
  selected or focused tab springs into view.
- Test harness: golden matrix, pattern checker, ink centering, IME tests,
  import rules, runtime motion.
