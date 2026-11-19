## 0.0.1-dev.0

Milestone M0, unreleased.

- `CoilCalendar`'s month view shows the year once, in the title: zooming
  out, the month leaves the title ("April 2020" to "2020") while its year
  holds still, and paging the years changes it; zooming in brings the
  month back. The pages lose their year heading, and the months take its
  room, so the calendar keeps its size. The month the title goes back to
  has a wash while it isn't the picked one. New
  `CoilCalendarLabels.yearLabel` and `showDaysLabel` name the title there
  for screen readers ("2020", "Back to the days of April 2020");
  `CoilCalendarLabels.year` is now that title.
- `CoilCalendar`'s month view pages sideways, one year per page, in the
  same space as the days (the zoom between them is unchanged). The title's
  year follows the page mid-swipe, the arrows turn a year there
  (`CoilCalendarLabels.previousYearLabel` / `nextYearLabel`), and the
  title, like Escape, zooms back into the month it names. In a sheet, a
  vertical drag on the months moves the sheet.
- Fix: the date picker lines up. Its popover hugs the calendar instead of
  matching the field's width, which left the calendar centered with edges
  nothing else shared. In a sheet, the month title, the days, the time
  band and the footer start and end on the sheet's 16 px text inset, with
  the title. In every calendar the title's text starts where the days
  start and the arrows' glyphs end where they end; the ghost buttons'
  padding hangs outside the grid. Days in a wide space grow up to 30 %
  (was 20 %) past their natural side, so a sheet fills on every phone.
  `CoilAdaptivePopup.minWidth` and `CoilCalendar.edgeInsetOf` are new.
- Breaking: `CoilCalendar` no longer shows the selected day in a chip
  beside the arrows while it's out of view; it read like a second title.
  `CoilCalendarLabels.selection` and `selectionLabel` are gone, and Tab no
  longer stops on the chip. Instead, `CoilDatePicker`'s footer names what
  Done will confirm: in the phone sheet and in a popover that also picks a
  time, the draft ("Fri, Nov 22, 2019", with the time when the picker picks
  one) sits on the footer's leading side and Done on its trailing side, at
  its own width rather than full width, however far the calendar has paged
  or zoomed. Before a pick it's empty, beside the disabled Done. A
  date-only popover still commits on the tap and has no footer. New
  `CoilCalendarLabels.summary` and `summaryLabel` ("Selected: Friday,
  November 22, 2019") localize it.
- Fix: a sheet dragged up past its rest showed the page below it. Its
  surface (fill, outline and dark-mode edge) now runs a window's height
  past its bottom edge, as `stupid_simple_sheet`'s `SheetBackground`
  extends its fill, so the sheet's own fill shows below it, also above
  the keyboard. The content keeps its size and its clearance of the home
  indicator.
- Breaking: the phone drawer's page edge shadow (`CoilDrawerReveal.behind`)
  is lighter, most of all in light mode, where the white veil made the old
  one read heavy: step 7 at half strength in light and step 8 at 70 % in
  dark, still centered on the edge with the `border` hairline.
  `CoilDrawerLook.edgeShadowLevel` is replaced by `edgeShadowLevelLight` /
  `edgeShadowLevelDark` and `edgeShadowAlphaLight` / `edgeShadowAlphaDark`;
  `shadows` / `drawerShadows` still override it.
- `CoilInput` places its slots by measuring them in the same layout pass
  as the text: a slot that fits a line (an icon, a "EUR" unit) stays
  inline; a taller one (a button) goes into the field's padding, centered
  and evenly inset with its corners concentric with the field's, so a
  trailing button no longer makes the field taller. The field grows only
  when the slot and `CoilInputStyle.slotInset` (4; 2 compact) on each side
  don't fit. Multi-line fields put inline slots on the first line and
  buttons in the bottom corner. `leadingPlacement` / `trailingPlacement`
  (`CoilInputSlotPlacement.auto`, `inline`, `inset`) override it. A
  `CoilButton` in a slot defaults to compact and the nested radius
  through `CoilInputSlotScope` (explicit `size:` and `style:` win), and on
  touch the field gives the button the taps around it.
- Breaking: `CoilDatePicker` holds what's picked as a draft until it's
  confirmed, and reports only the confirmed date. A popover picking a date
  alone confirms on the tap (as before); a popover with time and every
  sheet confirm with a **Done** button (`CoilCalendarLabels.confirm`),
  pinned in the sheet's footer. Closing any other way (close button,
  scrim, drag, back, Escape, a tap outside) cancels. Enter confirms
  (picking the focused day first on the grid); Space only picks.
- `CoilCalendar`'s month title follows the pages mid-swipe (it changes as
  soon as a page is more than half in view) with a blur-fade, and is a
  button with a chevron that zooms out to a month view: each year's
  months, 3 × 4, in a list that scrolls through the years, bounded and
  dimmed by `firstDate`/`lastDate`. Picking a month zooms back into its
  days; arrows, PageUp/PageDown, Enter and Escape work there too.
- `CoilCalendar.onSubmitted`: called after Enter picks a day.
- `CoilCalendarLabels` adds `monthLabel`, `monthName`, `year`,
  `chooseMonthLabel` and `confirm`.
- Fix: a drag that opens `CoilDrawer` (the phone sidebar) from a
  horizontal scrollable's edge no longer janks when it moves back: the
  drawer keeps the drag in both directions (`ScrollDragMode.dragFirst`)
  until it is back where the drag found it, then hands the rest of the
  gesture to the scrollable, like a sheet dragged down and back up. The
  same holds for a closing drag out of a scrollable in the panel, the end
  side and right to left.
- Breaking: the phone drawer revealed from behind (`CoilDrawerReveal.behind`,
  the sidebar's touch default) now lightens the page in light mode instead
  of darkening it: a veil of the top surface (white) at 35 %, fading in
  with the slide, so the page recedes into haze. Dark mode keeps dimming
  it, black 15 %, since a lighter page there reads as raised. The new
  `CoilDrawerLook.behindScrim(colors)` picks it and `behindVeilAlpha` sets
  the light veil; `behindScrimLight` is gone. The over reveal keeps the
  theme's `scrim`, and `scrimColor` / `drawerScrimColor` still override it.
- Breaking: `CoilFileThumbnail.size` (the side length, a `double`) is
  `dimension`, so `size` means the `CoilSize?` step everywhere in coil.
- Bold text: `CoilTheme.of` applies `CoilThemeData.boldText()` when
  `MediaQuery.boldTextOf` is true, so every role lighter than semibold
  becomes semibold (a variable font's `wght` axis too), as DESIGN.md
  specifies.
- Fix: `CoilSettingsDialog` no longer asks for a negative height in a
  window under 64 tall, and asserts it has a section.
- Fix: `CoilDataTable`'s search field shows a `query` set from code
  (clearing it clears the field).
- Fix: a popup shown as a sheet (`CoilSelect`, `CoilMultiSelect`,
  `CoilCombobox`, menus on a phone) rebuilds its content when the owner
  rebuilds, so options and values passed while it is open show in it.
- Fix: a centered or drawer `CoilModalRoute` closed while it springs in
  turns around with its momentum instead of from rest.
- Fix: `CoilTabs` keeps each tab's focus node, states and hover by its
  value, so inserting, removing or reordering tabs no longer moves focus
  or hover to another tab. Tab values must be distinct (asserted).
- Fix: `CoilRovingFocus` gives back the Tab stops it took
  (`skipTraversal`) when it switches to a stop on each item, a node leaves
  `nodes`, or the group goes away.
- Fix: a closing `CoilPopover` hands focus back only to an opener still
  in the tree (a removed one used to take focus while detached and keep
  it when it came back), and Tab can't move into a popover while it
  springs out.
- Fix: merged selection blocks in a right-to-left row (`CoilToggleGroup`)
  glide apart and together on their own side, rounding the outer corners
  and squaring the seam. `CoilLayerGeometry` has a `textDirection`
  (breaking for implementers outside coil), which the motion layer takes
  from `Directionality` and the highlight now paints with. Selection
  blocks draw their superellipse directly instead of allocating a
  `BoxPainter` per block per frame.
- `CoilFocusRing.borderRadius` takes a `BorderRadiusGeometry`, resolved
  with the ambient direction.
- Fix: `CoilThinkingIndicator` follows its words by position, so words a
  parent rebuilds (non-const `Text`s) and repeated words keep cycling
  instead of sticking on the first.
- Fix: `CoilThinkingSteps` grows in steps added after the list was
  cleared (a retry), not only steps past the first build's count.
- Fix: a style's state colors merge per state
  (`CoilComponentStyle.mergeStates`). A partial override such as
  `CoilButtonStyle(fill: WidgetStateProperty.fromMap({WidgetState.hovered: red}))`
  used to replace the whole fallback and crash at rest; it now keeps the
  lower layer's color for every state it doesn't name.
- Sheets have a header and a close button. `CoilSheetPanel` lays out its
  title and a new `CoilSheetCloseButton` on one 44 line whose middle runs
  through the top corner's center (36 down), with the round 36 button on
  that center, concentric with the 36 corner. On iOS and macOS the
  button leads and the title is centered; elsewhere the title starts
  with the rows' text and the button trails (`CoilSheetHeaderLayout`,
  `headerLayout:` to pin it). The title is one line and ends in an
  ellipsis before the button. The button is shown by default
  (`close: null` hides it, or pass your own), pops the route like a
  dismissal, is named "Close", takes the keyboard, and hides on a route
  that can't be popped. Search sheets (command menu, dropdown search,
  untitled combobox) put it at the end of the search line
  (`CoilSheetCloseSlot`, `CoilActionList.searchTrailing`,
  `CoilSheetPanel.lineTopOf`). A form dialog or settings dialog shown as
  a sheet uses the sheet's button (calling its `onClose`) and lines its
  body up with the title at 16; the settings title moves into the header.
  `CoilSheetRoute.cornerRadiusOf` gives the sheet's corner radius.
- Sheets have no grabber. `CoilSheetPanel` starts with a 12 gap
  (`CoilSheetPanel.topGap`) above its title or content; the sheet still
  drags anywhere.
- Sheets are coil's own. Breaking: `CoilSheetRoute` extends
  `stupid_simple_sheet`'s plain `StupidSimpleSheetRoute` instead of the
  glass sheet, so `blurBehindBarrier` and the glass route's other options
  are gone and `shape` is a `RoundedSuperellipseBorder`. The sheet paints
  a `CoilSurface` at the popover level (its fill, shadow and dark-mode
  edge) with the glass sheet's 36 superellipse top corners
  (`CoilSheetRoute.glassRadius`, scaled by the shape family), clipping its
  content. It dims the page with `CoilColors.scrim` (20 % light, 30 %
  dark) and no longer blurs it. It hugs its content: short content makes
  a short sheet on the bottom edge, and a scroll view grows it up to the
  top safe area or 5 % of the height. A sheet opened from a sheet slides
  over it with its own scrim; the one below no longer shrinks back.
  `CoilSheetRoute.scrollBehaviorOf` gives scrollables that take their own
  behavior one that still hands drags off to the sheet. Fixed: dragging
  the date picker's calendar or time columns in a sheet threw
  "'ScrollDragBehavior' is not a subtype of '_WrappedScrollBehavior'"
  under an app-wide `copyWith` scroll behavior.
- Controls can be lit. `CoilThemeData.plasticity` takes a
  `CoilPlasticity(amount:)` from 0 to 1: `.flat` (0, the default, which
  paints nothing), `.subtle` (0.5) and 1 for slightly brighter highlights
  and sheen, interpolated in between. It resolves per `CoilReliefRole` and
  brightness into a `CoilRelief` (gradient edge, rims, sheen, outside-only
  shadows), looked up with `CoilTheme.reliefOf(context, role)` and painted
  on a superellipse by `CoilRelief.decorate` (a `CoilReliefBorder`, which
  tweens with plain superellipses). Primary, secondary and destructive
  buttons are lit evenly. The button, checkbox, radio, switch, slider,
  select and input styles take a `plasticity` that wins over the theme's.
  Controls on a surface above the page stay flat: `CoilSurface` places a
  `CoilPlasticityScope(elevated:)` above `CoilPlasticity.flattenAbove` (1,
  the page, by default; raise it to light controls on cards or popovers
  too), and `CoilPlasticityScope(elevated: false)` lights a subtree again.
  `CoilTheme.plasticityOf` reads the plasticity before that flattening.
  Cards, popovers and dialogs are never lit. Breaking for earlier dev
  builds: `CoilPlasticity.soft`, `.tactile`, `scale`, the per-ingredient
  intensities (`edge`, `highlight`, `sheen`, ...), `roles`, `response`,
  `CoilReliefRole.floating` and `CoilCardStyle.plasticity` are gone; use
  `CoilPlasticity(amount:)`.
- `CoilCalendar` pages by swipe on touch: the month follows the finger, a
  swipe past half a page or a fling turns one month and anything less
  springs back, on `standard`. A trackpad swipe pages too; a mouse drag
  doesn't. Landing on a new month plays the `toggle` haptic, and only a
  finger's pick plays `pick` (Enter, Space and clicks pick silently).
- `CoilCalendar` and `CoilDatePicker` keep days square in any width: a
  wide sheet or popover grows the days at most 20 % past their natural
  side and centers the calendar (and the date picker's time columns)
  instead of stretching the days into wide rectangles. Every point of
  the grid picks a day, the focus ring's inset at the edges included.
  `CoilTimeColumns` is compact: five rows of a body line and the tier's
  gap (28 pointer, 34 touch), fading out toward the top and bottom, in
  tabular figures with a semibold colon; `CoilTimeColumns.visibleRows`.
- `CoilThinkingSteps` draws a connector under every step's glyph but the
  last's, following wrapping, text scale and RTL;
  `CoilThinkingStepsStyle.connectorColor`, `connectorWidth` and
  `connectorGap` style it.
- Fixed: a shown tooltip or open popover on a page another page covers no
  longer fails Flutter's `size == theater.size` assertion when the window
  resizes; it shows nothing while covered and is placed for the new size
  when uncovered.
- Fixed: `CoilScrollArea(scrollbar: .none)` no longer shows the platform's
  desktop scrollbar; an arrow a nested `CoilRovingFocus` or
  `CoilScrollArea` doesn't use (Down in a horizontal one) reaches the
  outer one; `CoilBanner` and `CoilSettingRow` work under
  `IntrinsicHeight`; a narrow calendar's days stay square; a short desktop
  window keeps the date picker's time under the calendar (only the touch
  tier puts it beside).

- Dialog and sheet buttons on phones are full width. A new primitive,
  `CoilActionBar`, lays out the buttons that end a dialog or a sheet: a
  trailing row on the pointer tier and in wide windows, and in a sheet or
  on the touch tier under 600 (centered confirmations too) every button at
  the full content width, 44 tall, stacked with the primary on top and
  Cancel at the bottom. `layout: CoilActionBarLayout { row, stack }`
  overrides the choice; `CoilActionBar.layoutOf` picks the stack in any
  `CoilSheetRoute` too, and `spacing` defaults to the tier's
  `CoilMetrics.gap`. `CoilDialog` uses it, and in a sheet pins it under
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
  dim with the new `CoilColors.scrim` token, black 20 % (light) / 30 %
  (dark) instead of 40 % / 50 %. `CoilSheetPanel` lost its own surface,
  margins and max width (`CoilSheetPanel.maxWidth` is now
  `CoilSheetRoute.maxWidth`), and `CoilSheetPanel.barrierColorOf` is gone;
  read `CoilTheme.of(context).colors.scrim`.
- The phone sidebar is revealed from behind the page. Below its
  breakpoint, on the touch tier, `CoilSidebarScaffold`'s page slides
  aside to show the sidebar, taking the screen's corner radius while it
  moves and squaring up once it covers the sidebar again; a horizontal
  drag anywhere on the page opens it, and horizontal scrollables hand
  over at their edge. The sidebar emerges as it is revealed, fading in
  from 40 % and growing from 0.95 at the page's edge (`drawerTransition`;
  no growth under reduced motion), and the page lifts
  off it: a veil (lightening in light, dimming in dark), shadow step 8
  centered on its side and a hairline in `border`, all following the drag.
  Where the screen's radius is unknown, phones round the page 40 (iOS) /
  24 (Android) by default (`drawerFallbackCornerRadius`). The pointer tier
  keeps the drawer over the page.
  New: `drawerReveal`, `drawerDrag`, `drawerWidth`, `drawerTransition`,
  `CoilSidebarStyle`'s `drawer…` look fields and `CoilSidebarTrigger.side`. Two nested
  scaffolds give a phone a sidebar on each side.
  - Breaking: `CoilDrawer` takes `start` and `end` panels,
    `open: CoilDrawerEdge?`, `onOpenChanged`, `startSemanticLabel` and
    `endSemanticLabel` (was `drawer`, `edge`, `open: bool`, `onClose`,
    `semanticLabel`), and `reveal:
    CoilDrawerReveal { behind, over }`, `drag: CoilDrawerDrag?` and look
    parameters. It renders in place instead of in an overlay.
  - Breaking: `CoilDrawer`'s look parameters are grouped: `look:
    CoilDrawerLook?` (`cornerRadius`, `fallbackCornerRadius`,
    `scrimColor`, `shadows`, `panelColor`, `contentColor`; null is
    `CoilDrawerLook.fallback(theme, reveal:)`) and `transition:
    CoilDrawerTransition` (`scale`, `panelScale`, `panelOpacity`). Its
    numbers are named constants: `CoilDrawer.maxWidth` (320),
    `.widthFraction` (0.85), `.flingVelocity` (400),
    `CoilDrawerLook.behindVeilAlpha` / `behindScrimDark`,
    `.edgeShadowLevel` and `.phoneCornerRadii`.
  - Breaking: `CoilSidebarStyle.drawerScale`, `drawerPanelScale` and
    `drawerPanelOpacity` moved to `CoilSidebarScaffold.drawerTransition`;
    `CoilSidebarStyle.fallback` now fills `drawerFallbackCornerRadius` and
    `drawerShadows`.
  - Breaking: `CoilDrawer.motion` is a `CoilMotion?` token set and
    `exitMotion` is gone; it slides on `standard` / `standardExit`, and
    reduced motion now applies to an app's own drawer motion too.
  - `CoilScreenRadius` (primitive) reads the device screen's corner radii
    once through `corner_radius_plugin`; null where unknown (web, desktop,
    a failed query, tests) and `BorderRadius.zero` for a square screen.
    It asks with a negative default radius, so a device the plugin can't
    place reads as unknown instead of square and the phone fallback
    applies; radii above 64 or a quarter of the screen's shortest side
    (Android before 12 reports physical pixels) count as unknown, only
    Android can answer square, and a query that finds nothing runs once
    more on the next read.
    coil now depends on `corner_radius_plugin` and `scroll_drag_detector`.
- Keys are Flutter shortcuts. Every coil widget maps its keys to intents
  in `Shortcuts` and handles them in `Actions`, instead of reading key
  events. Behavior is unchanged.
  - `CoilDismissIntent` is what Escape does in a popover, menu, select
    list, combobox, tooltip or drawer panel, and `CoilSliderStepIntent`
    (by a `CoilSliderIncrement`: a step or a page) and
    `CoilSliderLimitIntent` (to a `CoilSliderLimit`: min or max) are a
    slider's arrows, Page keys and Home/End. An app replaces any of them with its own `Actions` entry
    above the widget.
  - `CoilDefaultAction` is how a coil widget registers its action for
    those: like `Action.overridable`, but a nested popup skips the
    actions of the popups around it.
- New primitive `CoilCardStack`: a pile of cards that peeks folded and
  fans out into a list, for components to build on. `items:` are
  `CoilCardStackItem(key:, child:, slot:, lifted:, leaving:)`, front
  first; `anchor: CoilCardStackAnchor { bottom, top }`, `expand:
  CoilCardStackExpand { auto, always, never }`, `fold: CoilCardStackFold
  { onTapOutside, manual }`, `peek`, `peekScale`, `maxPeeks`, `gap`,
  `shift`, `background`, `leading`, `trailing`, `sideWidth`, `motion:`
  and `motions:` keyed by `CoilCardStackTrack { expand, slot, leave }`.
  `CoilCardStackController` holds the tap's pin (`pinned`, the tap's part
  of `auto`; cleared, with a notification, under `never` or below two
  cards) and reports `expanded`. Cards read their pile with
  `CoilCardStack.maybeExpandedOf` and leave it with
  `CoilCardStack.maybeLeaveOf`; a background reads the folded pile's
  extent with `CoilCardStack.pileExtentOf(constraints)`. It needs a
  bounded width, and a bounded height with a background; otherwise debug
  builds explain the fix (`Expanded`, `SizedBox`). Peeking cards scale
  with a plain transform, no image filter.
- New primitives for copy feedback: `CoilCopyController` (copy, the 2 s
  hold that a repeat only extends, the announcement and haptic; any
  clipboard failure shows `CoilCopyStatus.failed`), `CoilCopySwitcher`
  (the swap, keyed by status) and `CoilCopyGlyph` (copy glyph, drawn
  check or ×; `CoilCopyGlyph.listening(controller:)` follows a
  controller). Both take `motion:` and `motions:` keyed by
  `CoilCopyTrack { swap, draw }`. `CoilInputCopy` and a chat message's
  Copy action use them.
- `CoilSidebarCalloutStack` and `CoilQueuedStack` are built on
  `CoilCardStack`: fanned-out cards stack by their measured heights with
  the gap token, and folded peeks are even whatever the heights.
  - Breaking: `CoilSidebarCalloutStack.gap` (4) is removed; the pile uses
    the tier's `gap` (8 at pointer regular). Its `peek`, `maxPeeking` and
    `scaleStep` constants are removed too (they mirrored
    `CoilCardStack.defaultPeek`, `.defaultMaxPeeks`,
    `.defaultPeekScale`).
  - Breaking: `CoilSidebarCalloutStack` is a `StatelessWidget` (was
    stateful), and every card must have a key: a missing one is an
    assertion error instead of a silent `ValueKey(index)` that broke the
    dismiss animation.
  - Behavior: on touch, a tap on the callout pile fans it out until a tap
    outside it (touch never fanned before), and a tap on a peeking card
    fans the pile out instead of pressing what is under the peek.
  - `CoilQueuedStack` with `size:` spaces its cards by that size's gap
    (it used the ambient one while dragging by the sized one), and hides
    its collapse button once fewer than two messages are queued.
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

- `dart run coil_cli:eject <component>` copies a component into the app,
  and `dart run coil_cli:update` merges coil's later changes into the copy
  with `git merge-file` (see SKILL.md). Eject takes several components or
  `--all`, and names copies
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
- Breaking: `CoilSidebarController.attach` is gone; the scaffold attaches through
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
    `messageLabel`, `countLabel`). `CoilDrawer.label` became a
    screen-reader label (now `startSemanticLabel` / `endSemanticLabel`,
    see the phone sidebar entry).
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
  closes it, and system back, Escape and the scrim do too. Its current
  API is in the phone sidebar entry above.
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
  `CoilMotion`; `CoilTier` × `CoilSize` → `CoilMetrics`; `CoilTypography`;
  `CoilInputModality`; `CoilAdaptiveScope`.
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
  screen-reader support. `CoilRangeSlider` takes two values
  (`CoilRangeValues`); both take `steps` lists and a `valueDisplay`
  (`text`, `editable`, `tooltip`).
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
