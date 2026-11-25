## 0.1.0-dev.0

First preview of Coil — a Flutter design system built on [Motor](https://pub.dev/packages/motor) 2.0. Works under any `WidgetsApp` with no Material or Cupertino app shell. Requires Flutter 3.47 or later.

- **Components (39):**
  - **Controls:** `CoilButton` (including `brand`, `primary`, `secondary`, `destructive`, and icon-named buttons), `CoilBadge`, `CoilKbd`, `CoilCheckbox`, `CoilSwitch`, `CoilSlider`, `CoilRangeSlider`, `CoilInput` (single-line & `.multiline`), `CoilInputGroup`, `CoilInputCopy`, `CoilSkeleton`.
  - **Forms:** `CoilField`, `CoilFieldSet`, `CoilFieldGroup`, `CoilFieldSeparator`, `CoilCheckboxGroup`, `CoilRadioGroup`, `CoilToggleGroup`, `CoilTabs`, `CoilSelect`, `CoilMultiSelect`, `CoilCombobox`, `CoilCalendar`, `CoilDatePicker`.
  - **Menus & overlays:** `CoilDialog`, `CoilSettingsDialog`, `CoilTooltip`, `CoilDropdown`, `CoilContextMenu`, `CoilCommandMenu`.
  - **Layout & display:** `CoilAccordion`, `CoilCard`, `CoilTable`, `CoilDataTable`, `CoilBanner`, `CoilBreadcrumb`, `CoilScrollArea`, `CoilCarouselDots`, `CoilFileThumbnail`, `CoilReveal`, `CoilSidebarScaffold` & `CoilSidebar`.
  - **Chat:** `CoilChatMessage`, `CoilInputMessage`, `CoilQueuedStack`, `CoilThinkingSteps`, `CoilThinkingIndicator`, `CoilAskUserQuestions`.
- **Theming & motion:** `CoilTheme` / `CoilThemeData` with `CoilColors.fromSeed` (accessible or exact `brandFill` policy and opt-in `brandSelection`), superellipse `CoilShape` presets (`.rounded`, `.pill`, `.sharp`), `CoilTypography` presets for Allo and Inter, `CoilMotion` spring tokens, `TickerRateScope` fixed frame-rate support, `CoilTier` pointer/touch sizing, and `CoilThemeData.icons` role overrides.
- **Primitives & ejection:** Public building blocks in `package:coil/primitives.dart` (`CoilInteraction`, `CoilFocusRing`, `CoilPopover`, `CoilSheetRoute`, `CoilTextFieldCore`, and more), and component ejection/three-way updates via [`coil_cli`](https://pub.dev/packages/coil_cli).
- **Accessibility:** Semantics, keyboard navigation safe during IME composition, keyboard-only focus rings, 2× text scaling, high contrast, bold text, RTL, reduced motion, and 44 px touch targets.
