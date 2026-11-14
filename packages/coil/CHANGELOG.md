## 0.0.1-dev.0

Milestone M0, unreleased.

- Breaking: `primitives.dart` no longer exports internals.
  - `CoilMotionLayerHandle` is gone, and so is the `handle` parameter of
    `CoilMotionLayer`. Nothing used them.
  - `CoilSelectionRun` and `CoilSelectionRuns` are hidden; they are how
    `CoilSelectionBlocks` merges runs.
  - `CoilFocusAlwaysVisible` is hidden; `CoilTextFieldCore` applies it.
  - `CoilScrollbar` is hidden; `CoilScrollBehavior` and `CoilScrollArea`
    build it.

- Modals are routes too. `CoilModalRoute<T>` is the route every
  `showCoil…` modal pushes, and `CoilModalPage<T>` shows one from
  `Navigator.pages` or a router. With no `presentation`, it opens as a
  sheet on the touch tier in a compact window and centered elsewhere.
  Content reads its presentation with `CoilModalRoute.presentationOf`.
  - `CoilCommandMenu` is the command menu's panel, for showing it in a
    route; `showCoilCommandMenu` still opens it.
  - `CoilDialogKind.presentation` gives a dialog kind's presentation.
  - `showCoilModal` takes a nullable `presentation`; null is the adaptive
    choice above.
- `dart run coil:eject <component>` copies a component into the app, and
  `dart run coil:update` merges coil's later changes into the copy with
  `git merge-file`. See SKILL.md.
- `expectCoilPattern` and `CoilPattern` are public in
  `package:coil/testing.dart`, so apps can check their ejected copies.
- `package:coil/date_picker.dart` re-exports `CoilCalendarLabels` from
  `calendar.dart` instead of calendar's `src/`.
- Docs for agents ship in the package: `SKILL.md`, `doc/llms.txt` and a
  page per component in `doc/components/`.

- Breaking: visible text and icons are `Widget` parameters that the
  component styles. Strings stay only for screen readers (`semanticLabel`
  or a name ending in `Label`) and for matching (`searchText`).
  - `CoilOption`, `CoilAction` and `CoilSubmenu`: `label` is a `Widget`;
    the `child` override is gone. Add `searchText` where typeahead, a menu
    search or a combobox should find the entry; entries without it are
    skipped. `CoilOption.semanticLabel` names an icon-only option.
  - `CoilTab`, `CoilTableColumn`: `label` is a `Widget`, `child` is gone,
    and `semanticLabel` names a tab or column the label can't.
    `CoilDataColumn.label`, `CoilCrumb.label`, `CoilMenuLabel(…)`,
    `CoilThinkingStep.title` and `.detail` are widgets.
    `CoilAccordionItem.label` is a widget; `semanticLabel` names its panel.
  - `CoilSelect`, `CoilMultiSelect`, `CoilCombobox` and `CoilDatePicker`:
    `placeholder` is a widget. The combobox's `emptyLabel` is `empty`, a
    widget, and it filters and fills its field from `searchText`.
  - `CoilMenuSearch` takes `placeholder` and `empty` widgets and a
    `semanticLabel`. `showCoilCommandMenu` takes the same three.
  - `CoilThinkingIndicator.words` is a list of widgets.
  - `CoilChatMessage.time` is a widget; `timeLabel` is what screen readers
    hear. `CoilChatMessageAction` takes a `label` widget for its menu row
    and a `semanticLabel` for its button.
  - `CoilSkeletonRegion.label` is `semanticLabel`.
  - Labels classes: `CoilCalendarLabels` builds `monthTitle`, `weekday`
    and `date` widgets and has `dateLabel`, `dayLabel`,
    `previousMonthLabel` and `nextMonthLabel` for screen readers.
    `CoilInputCopyLabels` has `copy`, `copied` and `failed` widgets and
    `copyLabel`, `copiedLabel`, `copyFailedLabel` and
    `copyToClipboardLabel` strings. `CoilDataTableLabels` builds `count` and
    `page` widgets, takes a `search` widget, and adds `searchLabel`. The
    screen-reader fields of `CoilBreadcrumbLabels`, `CoilChatMessageLabels`,
    `CoilCarouselDotsLabels`, `CoilTableLabels` and `CoilDataTableLabels`
    end in `Label` (`navigationLabel`, `userLabel`, `slidesLabel`,
    `sortedAscendingLabel`, `previousPageLabel` and so on).
  - `CoilTypeahead.labels` is `searchTexts`.
  - `CoilAction` and `CoilSubmenu` gain `semanticLabel`, which names them
    where they show as an icon only, such as a sidebar row action (else
    their `searchText`).
  - `CoilInputMessage.placeholder` is a widget. `CoilQueuedStackLabels`
    fields end in `Label` (`editLabel`, `removeLabel`, `collapseLabel`,
    `messageLabel`, `countLabel`). `CoilDrawer.label` is `semanticLabel`.
- The sidebar is rebuilt to match FF's. `CoilSidebarScaffold` takes a
  `CoilSidebarController` (open state and width, which the app stores),
  `side`, `variant` (`sidebar`, `floating`, `inset`), `collapsible`
  (`offcanvas`, `none`) and `peek` (`hover`, `click`). A rail resizes it
  between 160 and 360 and folds it, and `[` / `]` or ⌘B toggle it; the
  outermost scaffold answers from launch. Below 768 it opens as a drawer.
  New parts: `CoilSidebarTrigger`, `CoilSidebarBar`, `CoilSidebarAction`,
  `CoilSidebarCalloutStack` and a collapsible `CoilSidebarGroup` with
  actions. Breaking: `CoilSidebarItem` takes a `label` widget and
  `leading` (was `icon`), and gains `status`, `actions` (menu entries,
  also a context menu; touch shows only the last), `children` and
  `expanded`; `CoilSidebarScaffold.of` returns the controller.
- `CoilSettingsDialog` and `showCoilSettingsDialog`: settings sections in a
  sidebar beside a panel, with `CoilSettingsList` and `CoilSettingRow`.
- `CoilKbd` draws a keyboard shortcut as key caps, from a string or a
  `ShortcutActivator`, in the ambient text color. In `CoilTooltip`'s
  `shortcut` slot the caps are 16 tall, so the bubble stays 24.
- `CoilDialogFrame` is the dialog's surface and close button without its
  layout; `CoilDialog` builds on it.
- `CoilDrawer` (primitive) shows a modal side drawer that stays a
  descendant of its owner, so it shows the app's current state. A drag
  closes it, and system back, Escape and the scrim do too.
- `CoilAskUserQuestions` asks an assistant's questions one at a time:
  single choice, multiple choice and typed answers, an optional typed
  "other" row, Back and Skip, and number keys on pointer. The card's height
  springs between questions. A `CoilAskUserQuestionsController` holds the
  step and the answers.
- `CoilColors.fromSeed` builds a palette from a brand color and a neutral
  tone (`neutralHue`, `neutralChroma`): every grey takes the tint at its
  default lightness and opacity, and text and status colors keep their
  contrast. The defaults give `CoilColors.light` and `CoilColors.dark`.
  `CoilColorMix` gains `oklch`, `toOklch` and `ensureContrastByLightness`.
- `CoilTypography.fontFamily` can be null for the platform's UI font
  (`CoilTypography.platform`). Breaking: `CoilTypography.copyWith` is
  removed, since a new family needs its own package. Use the constructor:
  `CoilTypography(fontFamily: 'Brand', fontPackage: null)`.
- `CoilColors.lerp` no longer pins the focus ring color: after a theme
  animation, focus rings still follow `brand`.
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
- Layout and display: `CoilScrollArea` (coil's scrollbar, edge fades,
  keyboard scrolling), `CoilAccordion`, `CoilThinkingSteps` and
  `CoilThinkingIndicator`, `CoilCard` and `CoilCardGroup`, `CoilTable`,
  `CoilBanner`, `CoilBreadcrumb` (collapses into a "…" menu),
  `CoilChatMessage`, `CoilCarouselDots`.
- Test harness: golden matrix, pattern checker, ink centering, IME tests,
  import rules, runtime motion.
