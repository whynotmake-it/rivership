## 0.0.1-dev.0

Milestone M0, unreleased.

- The unblurred modal scrim is a color token, `CoilColors.scrim` (black
  20 % light, 30 % dark). Breaking: `CoilSheetPanel.barrierColorOf` is
  gone; read `CoilTheme.of(context).colors.scrim`.
- Dialog and sheet buttons on phones are full width. A new primitive,
  `CoilActionBar`, lays out the buttons that end a dialog or a sheet: a
  trailing row on the pointer tier and in wide windows, and in a sheet or
  on the touch tier under 600 (centered confirmations too) every button at
  the full content width, 44 tall, stacked with the primary on top and
  Cancel at the bottom. `layout: CoilActionBarLayout { row, stack }`
  overrides the choice. `CoilDialog` uses it, and in a sheet pins it under
  the body with the new `CoilSheetPanel.footer`, which stays above the
  home indicator and the keyboard and shows a hairline while content
  continues beneath. Fixed: on the touch tier a button given a tight width
  (a stretched column) kept its own width and floated centered, because
  `CoilInteraction`'s minimum hit target loosened the constraints; the
  visual now takes the parent's size. A dialog's title in a sheet keeps
  the sheet title's two-line limit.
- Sheets are `stupid_simple_sheet`'s glass sheet. Breaking:
  `CoilSheetRoute` takes `context:` (and optional `motion:`,
  `barrierDismissible`, `barrierLabel`, `settings`) instead of `motion`,
  `barrierColor` and `capturedThemes`, and reads them from the theme.
  Sheets sit flush with the bottom edge, blur the page, stack on each
  other, ride on the keyboard and move on `gentle` both ways. They keep
  the glass sheet's scrim (black 15 %); dialogs and drawers, unblurred,
  dim with black 20 % (light) / 30 % (dark) instead of 40 % / 50 %.
  `CoilSheetPanel` lost its own surface, margins and max width
  (`CoilSheetPanel.maxWidth` is now `CoilSheetRoute.maxWidth`).
- The phone sidebar is revealed from behind the page. Below its
  breakpoint, on the touch tier, `CoilSidebarScaffold`'s page slides
  aside to show the sidebar, taking the screen's corner radius while it
  moves and squaring up once it covers the sidebar again; a horizontal
  drag anywhere on the page opens it, and horizontal scrollables hand
  over at their edge. The sidebar emerges as it is revealed, fading in
  from 40 % and growing from 0.95 at the page's edge (`drawerPanelOpacity`,
  `drawerPanelScale`; no growth under reduced motion), and the page lifts
  off it: a light scrim (7 % light, 15 % dark), shadow step 8
  centered on its side and a hairline in `border`, all following the drag.
  Where the screen's radius is unknown, phones round the page 40 (iOS) /
  24 (Android) by default (`drawerFallbackCornerRadius`). The pointer tier
  keeps the drawer over the page.
  New: `drawerReveal`, `drawerDrag`, `drawerWidth`, `CoilSidebarStyle`'s
  `drawer…` look fields and `CoilSidebarTrigger.side`. Two nested
  scaffolds give a phone a sidebar on each side.
  - Breaking: `CoilDrawer` takes `start` and `end` panels,
    `open: CoilDrawerEdge?` and `onOpenChanged` (was `drawer`, `edge`,
    `open: bool`, `onClose`, `semanticLabel`), and `reveal:
    CoilDrawerReveal { behind, over }`, `drag: CoilDrawerDrag?` and look
    parameters. It renders in place instead of in an overlay.
  - `CoilScreenRadius` (primitive) reads the device screen's corner radii
    once through `corner_radius_plugin`; null where unknown (web, desktop,
    a failed query, tests) and `BorderRadius.zero` for a square screen.
    coil now depends on `corner_radius_plugin` and `scroll_drag_detector`.
- Keys are Flutter shortcuts. Every coil widget maps its keys to intents
  in `Shortcuts` and handles them in `Actions`, instead of reading key
  events. Behavior is unchanged.
  - `CoilDismissIntent` is what Escape does in a popover, menu, select
    list, combobox, tooltip or drawer panel, and `CoilSliderStepIntent` and
    `CoilSliderLimitIntent` are a slider's arrows, Page keys and
    Home/End. An app replaces any of them with its own `Actions` entry
    above the widget.
  - `CoilDefaultAction` is how a coil widget registers its action for
    those: like `Action.overridable`, but a nested popup skips the
    actions of the popups around it.
- A queued stack card fits a narrow screen at a large text scale: when
  the message would get less room than the edit and remove buttons, they
  move to a line under it (and wrap if needed) instead of overflowing.
  Cards peeking behind the folded pile leave their buttons, drawn under
  the 44 hit target, out of semantics and offer Edit and Remove as
  actions on the card.
- The blur-fade is subtler. `CoilBlurFade` starts at a blur sigma of 1.5
  (`CoilBlurFade.defaultBlur`), down from 4, so popovers, tooltips, reveals
  and swaps soften as they arrive instead of smearing. Button and select
  swaps use half of it.
- coil scrolls the way the app does. Breaking: `CoilScrollBehavior` is
  removed. `CoilScrollArea` and menus no longer set a `ScrollBehavior`, so
  physics, overscroll and which pointers drag content come from the app's
  ambient one (Flutter's platform defaults unless the app sets its own).
  They still draw coil's scrollbar, `CoilScrollbar`, which is public again
  and turns off only the ambient behavior's scrollbar for its child.

- coil bundles no font. Breaking: the default typography is the
  platform's UI font, and apps that want Allo or Inter bundle it
  themselves and pick the tuned preset, `CoilTypography.allo()` or
  `CoilTypography.inter()`. In debug builds coil reports a typography
  whose font the app doesn't bundle.
  - `CoilTypography` holds the seven text roles of DESIGN.md §3.1 as
    plain `TextStyle`s for every tier and size step. `CoilTypography.from`
    puts the type scale on any base style. Each role sets the optical size
    to its font size.
  - `CoilTheme.textOf(context)` returns the roles for a widget's place in
    the foreground color, with `muted`, `brand` and `destructive`
    variants. `CoilTextTheme.emphasis` is the weight of titles and
    selected labels.
  - Breaking: `CoilWeight`, `CoilTypeStep` and `CoilMetrics.body`,
    `.field` and `.caption` are removed. Weights are plain `FontWeight`s.
- `CoilFocusRingTheme` holds the focus ring's width, gap and color.
  Breaking: it replaces `CoilThemeData.focusRingWidth` and
  `CoilColors.focusRingColor`.
- Springs live in component styles. Every animated component's style
  has a typed `motions` map, such as
  `CoilSwitchStyle.motions: Map<CoilSwitchTrack<Object>, Motion>?`, which
  merges key by key. A component's `motions:` still wins, then its style,
  then the tokens. `CoilRevealStyle` is new, and `CoilReveal` takes
  `style:`. Breaking: `CoilThemeData.trackMotions` is removed, and
  `CoilTheme.trackMotionOf` takes the resolved style's map as `styled:`.

- Surfaces follow the surface scope. A card, a dropdown or breadcrumb
  menu and the command menu take their level from the surface they sit
  on, so a card on a raised surface is lighter than it, and a menu opened
  from a card or a dialog opens above it. On the page nothing changes.
  - A card tells its content its level, and `CoilSurface.scope` does the
    same for any widget that paints its own surface.
  - `CoilCardStyle.surface` and `.shadows`, `CoilDropdownStyle.surface`
    and `CoilBreadcrumbStyle.surface` default to null, which follows the
    level. Set them to pin a color.
  - `CoilActionList.surface` is optional. Null fades the list's edges
    into the surface it sits on.
  - A submenu sits on its menu's level plus two (5 on the page); it used
    to share the menu's fill.

- `coil_cli:eject` takes several components or `--all`, and names copies
  after the app with `--prefix`, `--rename` and `--library`. The
  analyzer renames declarations, references, doc links and files; update
  renames coil's new version the same way before merging. Components
  ejected together, or later, use each other's copies, and copies come
  out with their imports sorted.
- Breaking: the eject tools and `expectCoilPattern` moved to the
  `coil_cli` package, a dev dependency (`dart run coil_cli:eject`,
  `package:coil_cli/testing.dart`). coil depends only on what it needs at
  runtime; `flutter_test` and the tools' packages are gone from its
  dependencies.
- `CoilSidebarController.attach` is gone; the scaffold attaches through
  a function `sidebar.dart` hides, so an ejected sidebar has no
  `@internal` member outside `lib/src/`.
- Breaking: `primitives.dart` no longer exports internals.
  - `CoilMotionLayerHandle` is gone, and so is the `handle` parameter of
    `CoilMotionLayer`. Nothing used them.
  - `CoilSelectionRun` and `CoilSelectionRuns` are hidden; they are how
    `CoilSelectionBlocks` merges runs.
  - `CoilFocusAlwaysVisible` is hidden; `CoilTextFieldCore` applies it.

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
- `dart run coil_cli:eject <component>` copies a component into the app, and
  `dart run coil_cli:update` merges coil's later changes into the copy with
  `git merge-file`. See SKILL.md.
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
