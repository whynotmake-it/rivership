## 0.1.0-dev.0

First preview of coil, a Flutter design system built on [Motor](https://pub.dev/packages/motor) springs. It works under any `WidgetsApp`, with no Material or Cupertino app shell. It needs Flutter 3.47 or later and Motor 2.0 pre-releases.

 - **Components:** `CoilButton`, `CoilBadge`, `CoilSkeleton`, `CoilCheckbox`, `CoilSwitch`, `CoilSlider`, `CoilTabs`, `CoilInput`, `CoilField`, `CoilSelect`, `CoilCombobox`, `CoilAccordion`, `CoilCard`, `CoilTable`, `CoilDataTable`, `CoilBanner`, `CoilBreadcrumb`, `CoilCalendar`, `CoilDatePicker`, `CoilDialog`, `CoilDropdown`, `CoilContextMenu`, `CoilCommandMenu`, `CoilTooltip`, `CoilSidebarScaffold`, `CoilSettingsDialog`, and chat pieces such as `CoilChatMessage`, `CoilInputMessage`, `CoilThinkingSteps` and `CoilAskUserQuestions`. Each has its own library, such as `package:coil/button.dart`.
 - **Pointer and touch:** components size and behave for the platform. Hover shows only from pointers that can hover, a press shows on touch-down, the focus ring shows only after keyboard use, and long menus open as sheets on phones.
 - **Motion:** every token in `CoilMotion` is a Motor spring, exits included, so an interrupted transition keeps its velocity. Override tokens app-wide, per subtree, per component or per track. Reduced motion is applied last.
 - **Theming:** `CoilThemeData` holds `CoilColors` (including `CoilColors.fromSeed`), `CoilTypography`, `CoilShape`, `CoilPlasticity`, `CoilHaptics` and the glyph map `CoilThemeData.icons`. Every rounded shape is a superellipse.
 - **Typography:** coil bundles no font. `CoilTypography.allo()` and `CoilTypography.inter()` are tuned for those fonts, and `CoilTypography.from` puts coil's type scale on any other.
 - **Haptics:** `CoilHapticEvent` covers toggles, picks, long presses, copies, sheet detents and drawers. A drawer taps when a drag crosses halfway, when a fling decides it, and when it opens or closes without a drag.
 - **Accessibility:** text scaling up to 2x, high contrast, bold text, reduced motion, right-to-left layouts, semantics and keyboard navigation.
 - **Ejecting:** `coil_cli` copies a component into your app so you can change its look, and later merges coil's changes into the copy. See `SKILL.md`.
 - **Catalog:** the app in `example/` shows every component, and bundles Allo and Inter.
