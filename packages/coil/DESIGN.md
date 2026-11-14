# coil design system

This document is the source of truth for how coil looks, moves and behaves, for people and for agents. It describes the **target** system: every component in scope, including those not built yet. Implementation sessions build against it. Where the Flutter package and this document disagree, one of them is a bug: fix the code, or update this document in the same change.

Values are logical pixels (pt/dp). Token names are the Dart names in `lib/src/foundation/`. The user's decisions on former open questions are recorded in [§17 Decisions](#17-decisions).

Contents: [1 Principles](#1-principles) · [2 Color](#2-color) · [3 Type](#3-type) · [4 Spacing and sizing](#4-spacing-and-sizing) · [5 Shape](#5-shape) · [6 Elevation and borders](#6-elevation-and-borders) · [7 Motion](#7-motion) · [8 Interaction](#8-interaction) · [9 Adaptivity](#9-adaptivity) · [10 Accessibility floor](#10-accessibility-floor) · [11 Iconography](#11-iconography) · [12 Writing](#12-writing) · [13 Shared anatomy](#13-shared-anatomy) · [14 Components](#14-components) · [15 Out of scope](#15-out-of-scope) · [16 Review checklist](#16-review-checklist) · [17 Decisions](#17-decisions)

---

## 1. Principles

- **Coil is a Flutter design system on Motor springs.** You use it like `material_ui` or `cupertino_ui`: import it under any `WidgetsApp`. It has no app shell and no Material dependency.
- **It's inspired by [Fluid Functionalism](https://www.fluidfunctionalism.com)** (MIT, credited in the README). From FF it takes:
  - the spacing rhythm and Inter type;
  - color restraint;
  - the gliding hover highlight;
  - merged selections;
  - the 1 px press collapse.

  These are a starting point, not a parity target. Where coil prefers something else, it changes it.
- **It's platform-idiomatic in behavior and one design in look.** Coil follows each OS where users have learned a convention: context-menu trigger, scroll physics, text selection, haptics, back gesture, modifier glyphs and hit-target size. Visuals, motion and component shapes are the same everywhere. Coil is never a Cupertino or Material skin: no ripple, no elevation tint, no 3D wheels.
- **Restraint.**
  - State is shown with neutral tints. Color is spent only on meaning (brand focus, switch on, destructive, status).
  - One highlight per list.
  - Hierarchy comes from spacing and weight, never from more boxes or lines.
- **A state lasts only as long as the input that caused it.** Hover lasts while a hovering pointer is over the element. Press lasts while something is down. The focus ring shows while the keyboard is the last input. Selection is the only persistent state, and it never looks like hover or press.
- **Everything retargetable is a spring.** Interrupting a transition keeps its velocity; nothing restarts.
- **Text scales and everything grows with it.** Heights are minimums (`pad + line box + pad`), never fixed.

## 2. Color

### 2.1 Neutrals and surfaces

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` = `surface(1)` | `#FAFAFA` | `#171717` | page |
| `surface(2)` | `#FCFCFC` | `#1E1E1E` | inset panels, sidebar `inset` card |
| `surface(3)` | `#FFFFFF` | `#252525` | popovers, sheets, cards |
| `surface(4)` | `#FFFFFF` | `#2C2C2C` | nested popover (submenu) |
| `surface(5)` | `#FFFFFF` | `#333333` | dialogs |
| `surface(6..8)` | `#FFFFFF` | `#3A3A3A` · `#414141` · `#484848` | rare stacking |
| `foreground` | `#171717` | `#F5F5F5` | text, primary button fill |
| `mutedForeground` | `#737373` | `#A3A3A3` | secondary text, resting pointer rows |
| `muted` | `#F4F4F5` | `#1E1E1E` | quiet fills |
| `accent` | `#E5E5E5` | `#525252` | neutral accent (switch-off track, gray badge) |
| `selected` | `#D4D4D4` | `#525252` | strong selection (slider fill base) |
| `input` | `#E5E5E5` | `#404040` | field chrome where a fill is needed |
| `border` | `foreground` @ 12 % | same | hairlines |

A surface opened from another surface sits **level + 2** for popovers and sheets, and **level + 4** for dialogs, capped at 8. Children read the level they sit on, so a popover inside a dialog is level 7.

### 2.2 State tints (separate tokens, never derived from accent)

| Token | Light | Dark | Use |
|---|---|---|---|
| `hover` | black 4 % | white 6 % | hover fill (pointer only) |
| `active` | black 7 % | white 10 % | pressed fill, selected fill, merged selection, tab pill |
| `tint` | black 8 % | white 25 % | secondary button |
| `tintHover` | black 6.5 % | white 20 % | secondary button hover |

**Hover is never colored.** The 4 / 7 % ladder is the whole state vocabulary.

### 2.3 Brand and status

| Token | Light | Dark | Use: the only places these appear |
|---|---|---|---|
| `brand` | `#6B97FF` | `#6B97FF` | focus ring, switch-on track, text selection (30 %), drop targets, the InputCopy flash, the today-dot in Calendar |
| `red` / `redLabel` | `#FB2C36` / `#C10007` | `#FB2C36` / `#FF6467` | destructive: 15 % fill (dark 20 %) under `redLabel` text. Never a solid red button |
| `destructive` | `#EF4444` | `#FCA5A5` | invalid borders (50 %), error text and icons |
| `info` / `success` / `warning` | `#3B82F6` / `#22C55E` / `#F59E0B` | `#93C5FD` / `#86EFAC` / `#FCD34D` | Banner icons and badges only |

Color mixes use **Oklab** (`CoilColorMix.oklab`). For example, primary hover is `foreground` 90 % into `background` and pressed is 80 %. sRGB lerps look visibly different, so don't use them.

### 2.4 High contrast

High contrast is driven by `MediaQuery.highContrastOf` and applied last (`CoilThemeData.highContrast()`):

- `borderAlpha` 12 % → **40 %**, so every hairline and field border is visible;
- `accent` is mixed 70 % toward `foreground`, which makes the selected and tab pills visible;
- the focus ring is darkened until it's ≥ 3 : 1 against the background, and it's 2 px wide;
- the checkbox draws a 1.5 px box around the checked tick, so all three states read in a 1-bit screenshot;
- pointer rows rest at `foreground`, not muted.

## 3. Type

**Family:** Inter Variable, bundled. Weights are `wght` + `opsz` pairs (`CoilWeight`), so a weight change keeps the advance width nearly constant:

| Weight | `wght` / `opsz` | Use |
|---|---|---|
| `normal` | 400 / 14 | body, resting labels |
| `semibold` | 550 / 18 | titles, selected items, buttons |
| `bold` | 700 / 25 | display only |

Never set a static `FontWeight` on top of the variation; the engine would synthesize bold.

**Leading** is CSS half-leading (`TextLeadingDistribution.even`). For Inter this centers the cap height in the line box exactly, so labels are optically centered with no nudging. A label that looks off-center is a layout bug, and the ink-measurement test catches it.

### 3.1 Roles

| Role | Pointer | Pointer compact | Touch | Touch compact | Weight | Use |
|---|---|---|---|---|---|---|
| display | 28/34 | 24/30 | 28/34 | 28/34 | bold | page titles (DataTable title) |
| title | 16/22 | 14/20 | **17/22** | 16/22 | semibold | dialog, sheet and card titles |
| subtitle | 14/20 | 13/18 | 16/22 | 15/20 | normal | chat bubbles, legends, command input |
| body | 13/20 | 12/18 | **16/22** | 14/20 | normal | controls, rows, paragraphs |
| field | 13/20 | 12/18 | **16/22** | 16/20 | normal | editable text (16 is iOS's no-zoom floor) |
| caption | 12/16 | 11/14 | 13/18 | 12/16 | normal | descriptions, group labels, tooltips, badges |
| micro | 11/14 | 11/14 | 11/14 | 11/14 | normal | counters, compact badges, key caps |

- **Why touch body is 16/22:** it keeps the pointer's text-to-height ratio (13 in 36 = 16 in 44 = 0.36), and Inter 16 reads like SF 17 (research 08).
- Numbers that line up (calendar cells, times, table numbers, counters) use `FontFeature.tabularFigures()`.
- **Weight changes never reflow.** A label that turns semibold when selected reserves the semibold width with an invisible copy (the "ghost span").
- **Rows truncate with an ellipsis and never wrap**, except where a component says it wraps (Field labels, CheckboxGroup labels, Banner text).

## 4. Spacing and sizing

### 4.1 Tiers and steps

- **Tier** (`CoilTier`) is the size set.
  - It latches by platform: desktop OS → `pointer`, phone or tablet → `touch`.
  - `CoilAdaptiveScope(tier:)` or the theme can pin it.
  - It never flips live. Whether something hovers or presses is decided by the kind of each pointer event, so a mouse on an iPad still hovers and a finger on a laptop presses.
- **Size step** (`CoilSize`) is `regular` or `compact`. Compact is one step denser, for toolbars, filter bars, sidebars and tables. `CoilAdaptiveScope(size:)` sets it for a subtree.

### 4.2 The ladder (`CoilMetrics`)

| Token | Pointer | Pointer compact | Touch | Touch compact |
|---|---|---|---|---|
| `controlHeight` (min) | 36 | 28 | 44 | 36 |
| `minHitTarget` | 0 | 0 | 44 | 44 |
| vertical pad = (h − line) / 2 | 8 | 5 | 11 | 8 |
| `controlPaddingX` (fields, triggers, tabs) | 12 | 10 | 16 | 12 |
| `itemPaddingX` (rows in a popup) | 8 | 6 | 10 | 6 |
| `popupInset` (popup edge → rows) | 4 | 4 | 6 | 6 |
| `gap` (glyph ↔ label, neighbors) | 8 | 4 | 12 | 8 |
| `iconSize` | 16 | 14 | 20 | 16 |
| `buttonPaddingX` / next to icon | 16 / 12 | 12 / 8 | 20 / 16 | 16 / 12 |
| `buttonGap` | 6 | 4 | 8 | 6 |
| `checkboxSize` / radius / glyph | 16 / 5 / 18 | 14 / 4 / 16 | 20 / 6 / 22 | 18 / 5 / 20 |
| switch track / thumb | 34×20 / 16 | 28×16 / 12 | 44×26 / 22 | 36×22 / 18 |
| `segmentPadding` | 4 | 2 | 4 | 2 |
| `triggerMinWidth` | 160 | 160 | 160 | 160 |

**The alignment rule:** `controlPaddingX = popupInset + itemPaddingX` (12 = 4 + 8, 10 = 4 + 6, 16 = 6 + 10, 12 = 6 + 6). A popover's row text therefore starts exactly where its trigger's text starts.

### 4.3 Layout spacing

| | Pointer | Touch |
|---|---|---|
| Page gutter (phone) | — | 16 |
| Page gutter (desktop content) | 24 | 24 |
| Label → control | 6 | 6 |
| Control → description / error | 4 | 6 |
| Field → field | 12 | 16 |
| Section → section | 24 | 32 |
| Dialog / card padding | 24 / 16 | 20 / 16 |
| Sheet margin from screen edges | — | 8, bottom `max(8, safe area)` |

Spacing values come from {2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 48}. If a value isn't in that set, it needs a reason in the code.

## 5. Shape

**Superellipses only.** Every rounded shape is a `RoundedSuperellipseBorder` / `ClipRSuperellipse` / `drawRSuperellipse`: pills (radius = height / 2), focus rings and merged runs included. An architecture test fails on `RRect`, `ClipRRect`, `RoundedRectangleBorder`, `StadiumBorder` and rounded `BoxDecoration`.

**Shape family** (`CoilShape`, theme-wide):

`CoilShape` resolves per tier (`CoilShape.radii(tier)`, `CoilTheme.radiiOf(context)`): touch controls are taller, so their corners grow to keep the same proportions. Pointer values are unchanged.

| | item (controls, rows, fills) | container (popovers, sheets, cards, groups) | focus ring |
|---|---|---|---|
| `rounded` (default), pointer | 8 | 12 | 10 |
| `rounded`, touch | 10 | 16 | 12 |
| `pill`, pointer | height / 2 (rows 20) | 24 | item + 2 |
| `pill`, touch | height / 2 (rows 22) | 28 | item + 2 |
| `sharp` | 1 | 1 | 3 |

Popups cap `pill` at `rounded`: a pill-shaped menu row looks like a button.

**Nesting:** outer radius = inner radius + the inset between them (`CoilShape.nested`).

- Popover / sheet = item + `popupInset` = the container radius: 8 + 4 = **12** pointer, 10 + 6 = **16** touch.
- The focus ring sits 2 px outside, so it's item + 2.
- A number-stepper button 4 px inside an input has radius item − 4.
- Every corner gap is even.

**Merged selection runs** round only their outer corners, at the item radius.

## 6. Elevation and borders

- **Hairline:** 1 px `border` (`foreground` @ 12 %, 40 % in high contrast). The checkbox and radio use 1.5 px.
- **Surface N pairs with shadow N** (`CoilColors.shadow(n)`):
  - Light: a 1 px `shadowColor` ring plus stacked drops (1, 3, 6, 12, 24, 48, 96 px; spread = −offset / 2) at black 6 %. Surfaces are white from level 3.
  - Dark: an outer black ring from level 3 (12 % + 2 % per level) and drops at black 18 %. Inside the shape, `insetRing(n)` draws a white ring at 2 % (levels 1–3), 4 % (4–5) or 6 % (6–8), and `topHighlight(n)` a 1 px white line along the top edge at 1 % (level 2), 2 % (3–4), 4 % (5–6) or 6 % (7–8). Don't skip them; they separate dark surfaces.
  - **Blur:** the recipes use CSS blur. A CSS blur of `B` has sigma `B / 2`, so `shadow()` converts it for Flutter's `BoxShadow` (the 1 px drop becomes a hard edge).
- **`CoilSurface`** paints all of this on a superellipse and tells its children their level: `min(ambient + offset, 8)`, with offset 2 for popovers, menus and sheets and 4 for dialogs. A popover in a dialog is level 7. `shadowLevel` pins the shadow weight while the fill follows the level.
- **Uses:** popover and sheet surface 3 / shadow 3; submenu 4 / 4; dialog 5 / 5; tooltip inverted (`foreground` fill, `background` text, no shadow).
- **Scrim** behind sheets, dialogs and drawers: black 40 % (light) / 50 % (dark).
- **No borders between rows.** Separators exist only as `role=separator` dividers in menus (between groups and before destructive items), Field separators, and table cell rules.

## 7. Motion

### 7.1 Tokens (`CoilMotion`, springs only)

| Token | Default (`CupertinoMotion`) | Moves |
|---|---|---|
| `quick` / `quickExit` | 100 ms / 80 ms, no bounce | hover highlight glide, press collapse, focus-ring travel, chevron rotate, tooltip and chip enter, switch squish, popover open/close on the pointer tier |
| `standard` / `standardExit` | 180 ms / 140 ms, no bounce | indicators that must land: tab pill, switch thumb, radio selected fill, merge/split, popover open/close on the touch tier, collapse heights, month paging, drawer, slider thumb settle, list reorder |
| `gentle` / `gentleExit` | 340 ms, bounce 0.1 / 260 ms | large surfaces: sheets, dialogs, full-screen pages, sidebar rail open/close, Banner appear |
| `fade` / `fadeExit` | 120 ms / 90 ms, no bounce | opacity and color: label colors, tints, rings fading, check and dash drawing, scrollbar visibility |

Two durations sit next to the springs:

- `minPressDuration` (90 ms): a quick tap still shows its press.
- `acknowledgeDuration` (300 ms): a picked row stays visible this long before the list closes.
- Spinner lap: 1 s. Skeleton grace: 160 ms. Skeleton pulse: 2 s.

Named holds that aren't tokens:

- **DatePicker close:** 200 ms after a pick.
- **InputCopy reset:** 2 s.
- **Tooltip timing:** 200 ms delay, 300 ms group skip-delay.

### 7.2 Rules

- **The bigger the thing, the softer the spring.** Only `gentle` bounces. No component invents a duration.
- **Exits are tighter springs, never curves**, so a reversed transition keeps its velocity. Enter always outlasts exit.
- **Overlays enter with the blur-fade** (`CoilBlurFade`): opacity 0 → 1, blur 4 → 0, scale 0.96 → 1, plus a 4 px slide from the resolved side (popovers, tooltips). Exits run it in reverse on the exit token.
- **Popovers follow the tier.** Pointer popovers open on `quick` and close on `quickExit`, like the original's popups (`spring.fast`). Touch popovers are bigger and open under a finger, so they use `standard` / `standardExit`. The tier comes from `CoilTheme.tierOf`, not the platform.
- **Scale an image, not the text.** While an overlay scales or slides, its content is drawn at rest size and the result is resampled (a matrix image filter, medium quality). Text drawn under an animated scale is re-rasterized every frame, and Impeller snaps each glyph to the pixel grid on its own, so letters jitter. At rest the content paints directly.
- **Gestures hand off their velocity:**
  - a sheet drag, drawer drag or switch flick releases into its spring with the fling velocity;
  - a switch decides by the projected position `x + v · 0.1 s`;
  - sliders don't fling: the value never coasts.
- **Snap on reflow.** A highlight, selected pill or active background springs when its *target* changes, and snaps when the target only moved because of layout.
- **Height collapses** (Accordion, groups, ThinkingSteps, Banner rows) animate a 0..1 height factor on `standard`. Opacity leads on `fade`, so content dissolves instead of being sliced. A child resizing inside an open region is instant.
- **No idle tickers.** Nothing animates at rest. The loops are spinners, the Skeleton pulse and the ThinkingIndicator's word cycle. Reduced motion stops the first two and turns the word cycle into a crossfade.

### 7.3 Customizing

- Tokens are runtime theme data. Set them app-wide on `CoilThemeData.motion`, per subtree with `CoilTheme.override`, or per instance with a component's `motion:`.
- Multi-part components expose typed tracks, such as `CoilSwitchTrack.thumb`, `.squish` and `.tint`. Override them per instance with `motions: {.thumb: …}` or app-wide with `CoilThemeData.trackMotions`.
- Components read the motion on every animation, so a change applies to the next animation.

### 7.4 Reduced motion

Reduced motion (`MediaQuery.disableAnimations`) is applied last:

- spatial tokens become `Motion.instant()`;
- `fade` / `fadeExit` stay, so opacity and color still transition (fewer and gentler, not none);
- overlays fade only, with no blur, scale or slide;
- loops (spinners, Skeleton pulse) stop. The ThinkingIndicator keeps its word cycle as a crossfade (§14.4), because the changing word is the content;
- the holds stay.

## 8. Interaction

### 8.1 States per modality

| State | Mouse / trackpad / hovering pen | Touch | Keyboard |
|---|---|---|---|
| **Hover** | `hover` fill, or the gliding highlight in lists; muted → foreground label; icon weight 400 → 533 | never | — |
| **Press** | buttons collapse 1 px per side; rows show no extra fill (the highlight is already there) | `active` fill on touch-down. Inside scrollables it waits `kPressTimeout` (100 ms); it clears on up, cancel, scroll start or a slide past 18 px; it shows for at least 90 ms | Space/Enter: the same pressed look while the key is held |
| **Focus-visible** | no ring after a click | no ring after a tap | 1 px `brand` ring 2 px outside, radius + 2; shows only while the keyboard is the last input (`CoilInputModality`) |
| **Selected** | `active` fill, foreground, semibold | same | same |
| **Disabled** | 50 % opacity, no hover, skipped by arrows | 40 % on touch rows | skipped |

Text fields are the exception: they show their focus border (`foreground` @ 40 %) however they were focused.

**No sticky states.** Nothing stays lit where a finger lifted.

**Touch rows rest at full foreground.** The muted → foreground fade means "the pointer is here", which a finger can't express.

### 8.2 The gliding highlight

- **One highlight per list** (`CoilHoverRegion`). It glides between rows on `quick` (`quickExit` when leaving) and fades on `fade`.
- **It starts fresh after empty space.** When the pointer re-enters a list, the highlight fades in at the row instead of sliding over from where it last was.
- **Keyboard focus moves it too:** arrows move the active item, and the highlight follows.
- **On touch it isn't a highlight.** It becomes the press fill in place: it never travels between taps and never stays.

### 8.3 The active item

Lists keep an **active item** separate from focus and hover (like `aria-activedescendant`):

- hover, the arrow keys and typeahead move it;
- Enter, Space and the soft keyboard's Search key act on it;
- in search and combobox lists, completed taps move it too.

**Typeahead:** a 1 s buffer, prefix-matched on `label`, searching from the active item and skipping disabled rows.

### 8.4 Merged selection

- Adjacent selected rows (or segments) share one `active` block with only its outer corners rounded.
- Selecting the row between two runs **merges** them: the edges converge on the bridging row and the inner corners stay round until the halves meet.
- Deselecting a row inside a run **splits** it: it snaps to the seam, then the halves diverge.
- Both run on `standard`.
- **Used by:** CheckboxGroup, ToggleGroup, multi-select lists, Combobox (multi), the Calendar range band, Sidebar multi-select and DataTable selection.
- In a popup the block is inset `popupInset`, so it's concentric with the panel.

### 8.5 Press collapse

- A filled button draws its fill 1 px inside its bounds plus a 1 px spread in the same color.
- Pressing collapses the spread, so the fill shrinks exactly 1 px per side at any width, on `quick`.
- There's **no scale**, on any platform.

### 8.6 Haptics (theme field, platform defaults)

| Event | iOS | Android | Desktop |
|---|---|---|---|
| Toggle flips (switch, checkbox), segment change | `selectionClick` | none | none |
| Pick in a sheet | `selectionClick` | none | none |
| Long-press menu opens | `mediumImpact` | `Feedback.forLongPress` | — |
| Sheet snaps to a detent | `lightImpact` | none | — |
| Copy succeeds (InputCopy) | `selectionClick` | `selectionClick` | none |

The table is `CoilHaptics.platform`. Set `CoilThemeData.haptics` to remap events, or to `CoilHaptics.none` to turn them off. Components play them with `CoilHaptics.play(context, event)`.

## 9. Adaptivity

### 9.1 Presentation: popover vs sheet

The presentation is decided **when an overlay opens**. An open overlay never morphs. First match wins:

1. The component's `presentation:` override.
2. `CoilAdaptiveScope(presentation:)`.
3. **Touch tier and window width < 600 → the phone rule:**
   - **sheet** if the overlay is a combobox, a date/time picker or the command menu, has search, is multi-select, has submenus nested 2 or more levels deep, or has more than 8 items;
   - otherwise an **anchored touch popover**.
4. Otherwise a popover.

The decision uses window width, not the platform: an iPad in a 320-wide split view is a phone.

### 9.2 Platform conventions

| | iOS / iPadOS | Android | macOS / Windows / Linux | Web |
|---|---|---|---|---|
| Context menu | long-press 500 ms | long-press 500 ms | right-click, Ctrl-click (macOS), Shift+F10, Menu key | as the input in use; our long-press on touch |
| Tooltips | hover only (trackpad, Pencil); none for touch | long-press on icon-only buttons | hover / focus | hover / focus |
| Scroll | bouncing, overlay bars | stretch, overlay bars | clamping, thin coil bar that widens on hover | browser's |
| Text selection | system edit menu (`SystemContextMenu`), Cupertino handles | Material handles and toolbar | coil-styled right-click menu | browser menu |
| Back | edge swipe pops routes | system / predictive back dismisses the top overlay | Esc | Esc / browser back |
| Modifier glyphs | ⌘ ⌥ ⇧ ⌃ | Ctrl Alt Shift | ⌘ on macOS, Ctrl elsewhere | by OS |
| Hit target | 44 | 44 (no 48 px Android hit box: Flutter has no hit slop, and a larger hit area without a larger layout needs a custom hit-test override) | — | per tier |

Coil never draws Cupertino or Material chrome. Platform pieces come in only where they're genuinely native: the edit menu, selection handles and the keyboard. They're used only inside `CoilTextFieldCore`.

**No edge-swipe drawers by default.** They fight the iOS back gesture.

### 9.3 Every overlay

- Dismiss with Esc, a scrim or outside tap, system back, and drag (sheets).
- Focus returns to the trigger.
- The payload survives the exit animation.
- `open()` resolves once, with a reason.
- A search field in a sheet opened by touch is **not** autofocused (it would throw the keyboard over the list). Combobox and CommandMenu are the exceptions: typing is the point.

## 10. Accessibility floor

Every component ships with all of these. They're required to call it done.

- **Text scaling** up to 2×, with goldens at 1, 1.5 and 2. Rows and controls grow, and icons scale through `IconThemeData.applyTextScaling`. Gaps and paddings don't scale.
- **High contrast** (§2.4) and **bold text** (`MediaQuery.boldTextOf`: normal → semibold).
- **Contrast:**
  - body text ≥ 4.5 : 1;
  - muted text on its surface ≥ 4.5 : 1 for content, 3 : 1 for placeholders;
  - focus ring ≥ 3 : 1;
  - the switch-off track ≥ 3 : 1 against its surface in high contrast.
- **Hit targets** ≥ 44 on touch, on every platform, Android included. The box that receives taps is the control's layout box (`minHitTarget` pads it out), never a hit-test override. A control inside a row that's already the target shrink-wraps (`CoilTapTargetSize.shrinkWrap`).
- **Semantics:** correct roles (button, checkbox, mixed, switch/toggled, radio in a mutually exclusive group, slider/adjustable, menu/menuItem, tab, textField, header, table/row/cell), names and states. Rows merge their parts into one node.
- **Live regions:** Banner (polite; assertive for destructive), copy results, command and combobox result counts, Field errors.
- **Keyboard:** everything reachable and operable, with the patterns in §14. Arrow and Enter interception respects IME composition (`value.composing`).
- **RTL:** layouts mirror, and directional glyphs (chevrons, arrows) flip. Progress and slider direction follow `Directionality`.
- **Reduced motion** (§7.4).
- No information lives only in hover or only in a tooltip.

## 11. Iconography

- **Coil bundles no icon set.** Icon slots take any `Widget` and are styled by Flutter's `IconTheme`:
  - `size` = `iconSize` for the tier;
  - `color` = the label's current color;
  - `weight` = 400 at rest, 533 when hovered or active (`CoilIconWeight`, the 1.5 → 2 stroke);
  - `applyTextScaling: true`.
- Variable icon fonts read `weight` directly. Stroke icons scale their stroke by `1.5 · weight / 400`.
- **Glyphs a component draws itself** (checkbox tick and dash, select check, chevrons, spinner, radio dot) are private painters on a 24-unit grid with stroke 2 and round caps. They size through `CoilIconSize.of(context)`, and each can be replaced through a slot or builder (`checkmark:`, `indicator:`, `glyphBuilder:`, `loadingIndicator:`).
- **Icons are optional decoration.** Never put meaning only in an icon: icon-only buttons need `semanticLabel`.

## 12. Writing

- **Labels are short verbs or nouns in sentence case:** "New file", "Save changes", "Delete project". No Title Case and no trailing punctuation.
- **Buttons say what happens:** "Delete project", not "OK". A destructive confirm repeats the verb from the title.
- **Menus:**
  - verbs for actions, nouns for choices;
  - no ellipsis unless the item opens a dialog that asks for more ("Rename…");
  - destructive items go last, after a separator.
- **Placeholders are examples or hints, never labels.** A field always has a label (`labelHidden` only for an obvious inline search).
- **Errors** say what to do: "Enter an email address like ada@example.com". No "Invalid input".
- **Descriptions** are one sentence, without "This field…".
- **Empty states** say what's missing and offer the next action: "No results for 'xyz'" plus a "Clear search" action.
- **Times and dates** use the locale (`intl`), 12/24 h from `MediaQuery.alwaysUse24HourFormat`. Ranges use an en dash ("Nov 13 – 15").
- Keep labels short enough to fit 160 at body size. If a label truncates, the full text must be reachable another way (menu, semantics).

## 13. Shared anatomy

### 13.1 Row (menus, selects, lists, groups)

```
| inset | pad | [leading] gap | label                 | gap [trailing] | pad | inset |
                              | description (caption) |
```

| | Pointer | Pointer compact | Touch | Touch compact |
|---|---|---|---|---|
| Min height, one line | 36 | 28 | 44 | 36 (44 hit) |
| Min height, two lines (label + description) | 52 | 40 | 60 | 52 |
| Leading glyph | 16 | 14 | 20 | 16 |
| Avatar / tile in two-line rows | 24 | 20 | 32 | 24 |
| Trailing slot | check, value (muted), chevron, shortcut caps (pointer only), badge | same | same, no shortcut caps | same |

- Label colors: pointer rows rest at `mutedForeground` and turn `foreground` when lit, selected or checked. Touch rows rest at `foreground`.
- The trailing check is the text color (`foreground`) in menus, popovers and sheets, never `brand`.
- **No separators between rows.** A check slot keeps its width when empty.
- A trailing check means single choice. A leading checkbox means a standalone checklist (CheckboxGroup). A merged fill plus a check means multi-select in a menu.

### 13.2 Popup surface

- Surface 3 / shadow 3; radius = container (item + `popupInset`: 12 pointer, 16 touch); inset `popupInset`.
- Width ≥ the trigger's (menus default to 288 pointer, `max(trigger, 220)` touch).
- Max height `min(480, available)` for menus, 300 for pointer selects; touch popovers are uncapped (≤ 8 rows).
- 6 px from the anchor; flips to the side with room; 8 px from window edges.
- Enter with the blur-fade from the resolved side: `quick` / `quickExit` on pointer, `standard` / `standardExit` on touch (§7.2).
- Lists scroll inside a ScrollArea with 32 px edge fades.

### 13.3 Sheet

- A floating panel 8 from the screen edges; the bottom is `max(8, safe area)`. The top is capped at the top safe area + 48, so the page always shows behind it. Centered at most 560 wide.
- Surface 3 / shadow 3, radius = the touch container radius (16).
- Grabber 36×5 (foreground 16 %), 6 above and below.
- Optional title: 17/22 semibold `foreground`, aligned with the row text, 4 above and 6 below, `Semantics(header)`.
- **Optional pinned header row:**
  - a search field (44, not autofocused on touch, kept above the keyboard);
  - or, for push navigation, a back row ("‹ Parent").
- A scroll-edge hairline (`border`) under the header shows only while content is scrolled beneath it, read from the list's scroll notifications, fading on `fade` / `fadeExit`. At the top there is no line.
- **Sections:** a caption 13/18 semibold muted label, 16 above and 4 below.
- **Optional action bar:** full-width 44 buttons above the safe area, stacked with the primary on top.
- **Height:** content height up to the cap; long lists scroll inside. Search and command sheets open at the large detent and grow while the keyboard is up.
- **Motion:** in on `gentle`, out on the drag's velocity. The scrim fades on `fade`.
- **Dismiss:** drag down, tap the scrim, system back, Esc.
- **Rows** are always touch rows, whatever the tier.

### 13.4 Focus ring

1 px `brand` (2 px in high contrast), 2 px outside the element, radius = element radius + 2. In lists **one ring** travels between rows on `quick` and fades on `fade`. Inside clipping parents (ScrollArea, table cells) the ring is inset by 1 instead.

---

## 14. Components

Every component follows §8 and §10. Each entry gives anatomy, sizes, states, motion, pointer vs touch, keyboard and semantics, then do/don't. "P / Pc / T / Tc" = pointer, pointer compact, touch, touch compact.

### 14.1 Leaf controls

#### Button

- **Anatomy:** fill → [leading] label [trailing]; icon-only is square.
- **Sizes** (height · padding · gap):

  | | P | Pc | T | Tc |
  |---|---|---|---|---|
  | Labeled | 36 · 16 (12 next to icon) · 6 | 28 · 12/8 · 4 | 44 · 20/16 · 8 | 36 · 16/12 · 6, 44 hit |
  | Icon-only | 36 | 28 | 44 | 36 visual, 44 hit |

  The label is body semibold.
- **Variants:**

  | Variant | Rest | Hover | Pressed / selected | Label |
  |---|---|---|---|---|
  | primary | `foreground` | 90 % Oklab toward background | 80 % | `background` |
  | secondary | `tint` | `tintHover` | `tint` | foreground |
  | tertiary | clear, hairline | `hover` | `active` | foreground |
  | ghost | clear | `hover` | `active` | muted → foreground |
  | destructive | red 15 % (dark 20 %) | 25 % (30 %) | 15 % | `redLabel` |

- **States:**
  - `loading`: a spinner replaces the leading slot (or the icon) with the width locked, at full strength, `Semantics(value: 'Loading')`.
  - `selected`: held pressed colors, for a menu trigger while its menu shows.
  - Disabled: 50 %.
- **Motion:** fill and label colors on `fade`; press collapse on `quick` (release on `standard`); icon weight on `fade`; leading/loading swap with the blur-fade on `quick`.
- **Keyboard:** Enter or Space activates.
- **Do:** one primary per view; destructive actions as `destructive` with a confirm.
- **Don't:** scale on press; ripple; a solid red button; two primaries side by side.

#### Badge

- **Anatomy:** [dot 7 (6 compact)] label (micro/caption).
- **Sizes:** P 24 high, padding 10, caption, gap 6. Compact: 20, padding 8, micro, gap 4. **No touch bump.** A badge isn't interactive.
- **Variants:**
  - `solid`: the hue at 15 % into the background, foreground text; gray uses `accent`.
  - `dot`: hairline outline, foreground text, colored dot.
  - `ghost`: no outline, no padding, inherits text color.
  - Colors: gray (default), brand, and the Tailwind-500 hues (red … rose).
- **Shape:** item radius, `pill` → full.
- **Motion:** none. When a host adds one (ThinkingSteps sources), scale 0.85 → 1 + fade on `standard`.
- **Semantics:** plain text; the dot is excluded.
- **Do:** status and categories.
- **Don't:** make it tappable; use a Chip-like Button instead.

#### Checkbox

- **Anatomy:** a box (1.5 px border); when checked, a bare tick with no box (FF's signature); a dash when null.
- **Sizes:** box 16 / 14 / 20 / 18, radius 5 / 4 / 6 / 5, glyph 18 / 16 / 22 / 20. Hit box 44 on touch. Inside a row, use `CoilCheckboxIndicator`, which has no hit box of its own.
- **States:**
  - unchecked: `border`; hover: foreground 40 %; invalid: destructive 50 %;
  - checked / indeterminate: border transparent; hover brings the 40 % border back;
  - disabled: 50 %.
  - High contrast draws the box around the tick.
- **API:** `value: bool?` + `tristate`. A tap cycles false → true → (null) → false.
- **Motion:** the tick draws on `fade` and retracts on `fadeExit`; check ↔ dash re-keys (old retracts, new draws); border on `fade`.
- **Keyboard:** Space toggles. Enter toggles only inside a choice card (Field).
- **Semantics:** `checked`, `mixed`, `enabled`, label from the Field.
- **Do:** use it for independent on/off in forms, with a visible label.
- **Don't:** use it for a setting that applies immediately (use Switch).

#### Switch

- **Anatomy:** track → thumb, plus an optional label. The whole row is the target.
- **Sizes:** see §4.2. The thumb is inset 2. Hover grows the thumb +2 (pointer only, into a pill). Press widens it +4 and flattens it −4 (+5 / −5 on touch). The labeled row's vertical padding is (row − track) / 2.
- **Colors:**
  - off: `accent`; on: `brand`;
  - hover shifts the track 10 % toward `overlay` (off) or 8 % toward black (on), in Oklab;
  - thumb white with `shadow(2)`;
  - the label is muted when off and foreground when on (pointer); always foreground on touch.
- **Motion** (tracks `CoilSwitchTrack.thumb` / `.squish` / `.tint`):
  - thumb on `standard`, squish on `quick`, tint on `fade`;
  - dragging sets the thumb directly and may overshoot 0.15 of the travel, stretching the track;
  - release decides by `x + v · 0.1 s` and animates with the release velocity.
- **Keyboard:** Space or Enter toggles. The focus ring hugs the track with a 2 px `background` gap.
- **Semantics:** `toggled`, label.
- **Haptic:** iOS `selectionClick` when the value flips mid-drag.
- **Do:** use it for settings that apply immediately.
- **Don't:** use it in forms that need Submit; don't copy iOS's 51×31.

#### Input

- **Anatomy:** a hairline field → [leading muted icon] text [trailing slot].
- **Sizes:** height = `controlHeight`, padding `controlPaddingX`, field text role.
- **States:**
  - rest: `border`, transparent; hover (pointer): `hover` fill;
  - focus: border `foreground` @ 40 %, hover fill removed (shown for any focus);
  - invalid: `destructive` 50 % (focus wins); disabled: 50 %; read-only: no hover.
- **Number variant:** two stepper buttons inset 4 (2 compact) at the trailing edge, 28 / 24 / 36 visual (44 hit on touch), radius item − 4, muted → foreground on hover. Long-press repeats with acceleration (400 ms, then every 80 ms, then 40 ms). Up and Down step.
- **Motion:** border and fill on `fade`.
- **Platform:** `keyboardType`, `textInputAction`, `autofillHints` and `textCapitalization` per use; autocorrect and suggestions are forced off while obscured; `scrollPadding` clears the keyboard by 16; native selection, magnifier and edit menu.
- **Enter:** single-line Return is the input action (`onSubmitted`); a Return that commits an IME composition only commits.
- **Keyboard:** native editing; IME-safe.
- **Do:** always pair it with a Field label.
- **Don't:** put a focus ring on fields; use the placeholder as the label.

#### Textarea

- **`CoilInput.multiline`:** the same widget, chrome and style as Input. It grows from 3 lines to 10, then scrolls. Leading and trailing slots sit on the first line.
- **Radius:** the item radius, capped at the `rounded` container radius (12 / 16), so a `pill` shape doesn't make a capsule.
- **Sizes:** min 3 lines and max 10, each plus the vertical pad. The first line aligns with Input text.
- **Motion:** growth is instant; colors on `fade`.
- **Keyboard:** Return inserts a newline. (Composers decide sending; see InputMessage.)
- **Don't:** animate growth (it jitters while typing).

#### Skeleton

- **Anatomy:** a block in `hover` tint at the item radius (text lines: line-box height × 0.6, full radius).
- **Motion:** after a 160 ms grace period it fades in over `fade`, then pulses opacity 1 → 0.5 → 1 every 2 s. Reduced motion keeps the grace and the fade, and drops the pulse.
- **Semantics:** excluded. The loading region carries `Semantics(label: 'Loading', liveRegion)`.
- **Do:** match the final layout's line count and widths. Text lines vary between 55 and 82 % of the width.
- **Don't:** shimmer.

### 14.2 Grouped controls

#### Field (FieldSet, Legend, Field, Label, Description, Error, Separator, ChoiceCard)

- **Anatomy:** a label (body; muted when stacked, foreground beside a control), the control, a description (caption muted), and an error (caption `destructive` with a 14 alert icon, live region). These are Widget slots, not discovery.
- **Orientation:**
  - `vertical`: gaps 6 and 4 (touch 6 and 6);
  - `horizontal`: label left, control right, `gap`;
  - `responsive`: vertical below 448 of group width, horizontal above.
- **Spacing:** fields 12 apart (touch 16). FieldSet legend: subtitle semibold, 4 below.
- **ChoiceCard:** a horizontal Field inside a bordered container at the container radius, padding 12 (10 compact, 16 touch). The whole card is the target. Hover (pointer) is the `hover` fill. Checked: border `foreground` 40 %. Keyboard focus rings the card.
- **Separator:** 20 high with a hairline, optionally with a centered caption label.
- **Required:** a muted ` *` after the label (excluded from semantics) plus the `isRequired` semantics flag.
- **Horizontal:** label and description share the row 1 : 1 with the control, which sits at the trailing edge.
- **Semantics:** one node per field. Label, description and error join the control's label, in that order, so they're read with its role and value. The node carries `isRequired` and `validationResult`, and is a live region while an error shows.
- **Label tap:** runs the control's label action (`CoilFieldControl`): text fields focus, toggles toggle.
- **One control per Field.** A group of controls goes in a FieldSet, a container with a header legend.
- **Invalid:** the label turns `destructive`, and the control gets its invalid look.

#### CheckboxGroup (built)

- **Anatomy:** a column of rows: [checkbox] label. Labels wrap and grow the row.
- **Sizes:** row = §13.1. The checkbox shrink-wraps inside the row.
- **States:**
  - checked rows merge into one `active` block (§8.4);
  - the pointer highlight glides on top;
  - the label is foreground (it rests muted on pointer when unchecked).
- **Motion:** merge/split on `standard`, highlight `quick`, tick `fade`, ring `quick`.
- **Keyboard:** each row is a tab stop. Up and Down move with wrapping; Home and End jump; Space or Enter toggles.
- **Semantics:** a group with a label; rows are `checked`.
- **Touch:** press fill only. Selection is the merged blocks.
- **Do:** use it for 2–10 related options.
- **Don't:** use it for mutually exclusive options.

#### RadioGroup

- **Anatomy:** rows of [radio] label. The radio is a 16 / 14 / 20 / 18 circle, 1.5 px border, with a dot 8 / 7 / 10 / 9.
- **States:**
  - **one selected fill (`active`) glides between rows** on `standard`;
  - the selected label is semibold foreground (with a ghost width);
  - the selected radio's border is transparent and its dot is foreground;
  - hover is the gliding highlight.
- **Motion:** dot in from scale 0.3 + fade on `quick`, out on `fadeExit` (bespoke and short); selected fill `standard`.
- **Keyboard:** roving focus, so the selected row is the tab stop. Arrows move *and* select, with wrapping; Home and End jump.
- **Semantics:** `inMutuallyExclusiveGroup`, `checked`.
- **API:** generic `CoilRadioGroup<T>(value, onChanged, options)`.
- **Don't:** use it for more than 7 options (use Select).

#### ToggleGroup (built)

- **Anatomy:** a horizontal segmented row with `segmentPadding`. Selected segments merge into one block.
- **Sizes:** segment height `controlHeight`, padding `controlPaddingX`.
- **Motion:** merge/split `standard`, highlight `quick`.
- **Keyboard:** roving; Left and Right move; Space toggles.
- **Semantics:** toggle buttons with `selected`.
- **Use:** multi-select formatting (Bold / Italic). For single choice use Tabs or a RadioGroup.

#### Slider (built)

- **Anatomy:**
  - **Row** (variants `scrubber`, the default, and `pips`): a full-width bordered row, `controlHeight` tall, with the label at the start and the value at the end (tabular, muted). The fill is `active` and a handle line sits at the value. `pips` adds a 5 px dot per step, left out where the label or value sits. The range spans the row edge to edge: the fill is empty at min and full at max, and the end pips sit under the handle line.
  - **Pill** (variant `pill`): an 18 high pill track with a 1 px `border` and a 16 white knob in a 20 box, between the label and the value; fill `selected` 50 % (dark `accent` 40 %).
- **Sizes:** `size` changes sizes only: the row is `controlHeight` (36 / 28 pointer, 44 / 42 touch) with `controlPaddingX`. On touch the pill's knob is 22 visual, 44 hit.
- **States:** the label and value turn foreground and semibold (with ghost width) while hovered, pressed or focused. Pips: dots at 30 % muted, the active one foreground. Disabled 50 %.
- **Pointer extras:** hover shows a preview bar (`accent` 40 %) toward the snapped hover value, plus the value bubble (the touch bubble, shown at the hover value) until a Tooltip exists.
- **Touch:** no preview. **A value bubble** (tooltip style) sits 8 + 24 above the thumb while pressed and fades on `fade` / `fadeExit`. Tapping the track jumps; dragging sets the value directly with no fling.
- **Motion:** thumb and fill settle on `standard` after a jump or keyboard step; follow the finger 1:1 while dragging a continuous slider; with divisions they spring to each step and retarget as the pointer crosses steps; handle and color on `fade`; pip growth `standard`.
- **Keyboard:** arrows ±step; PageUp/PageDown and Shift+arrow ±10 %; Home and End go to min and max. Click-to-edit value (P1): the number becomes a field.
- **Semantics:** `slider` / adjustable, a formatted `value`, increase and decrease actions; range thumbs are named "minimum" and "maximum".
- **Scope:** single value in v1; range, step lists, click-to-edit and tooltip mode in v1.x.

#### Tabs (built)

- **Anatomy:** a row of tabs: [icon] label. The **selected pill** (`active`) sits under the selected tab.
- **Sizes:** tab height `controlHeight`, padding `controlPaddingX`, icon gap `gap`.
- **States:** selected is foreground semibold (ghost width) with icon weight 533; others are muted; hover is a lighter pill (`active` @ 40 %) that grows out of the selected pill (pointer only).
- **`labels: CoilTabLabels`:** `always` or `selected` (unselected tabs show the icon only, and the label width springs).
- **Motion:** selected pill `standard`; hover pill `quick` (glides back into the selected pill on leave); ring `quick`; label width `quick`; scroll into view `standard`.
- **Overflow:** the strip scrolls horizontally with 24 px edge fades, and the selected tab scrolls into view on `standard`.
- **Touch:** no hover pill. Swipe between panels is opt-in. iOS `selectionClick` on change.
- **Keyboard:** roving; arrows move focus, Enter or Space selects (manual activation); Home and End jump.
- **Semantics:** tab, `selected`.
- **Do:** use it for 2–6 peer views.
- **Don't:** use tabs as navigation between pages of a flow.

#### InputGroup

- **Anatomy:** a column of labeled Inputs sharing one hover scope. The field nearest the pointer gets the `hover` fill; nothing glides.
- **Spacing:** 12 between fields (touch 16). Errors sit under each field.
- **Keyboard:** Tab between fields. A tap anywhere in a field's box focuses its text.
- **Touch:** no hover, only focus states.

#### InputCopy

- **Anatomy:** a read-only row (monospace value, truncated) plus a copy action: `icon` or `button` ("Copy"), on the trailing side or with `align: start`. Label it with a Field: a tap on the label copies.
- **Sizes:** row = `controlHeight`, padding `controlPaddingX`.
- **States:**
  - idle;
  - hover (pointer): the value gets a `brand` 20 % mark and the action turns foreground;
  - after a copy: `copied` (check) or `failed` (× in destructive) for 2 s, then idle.
  - The button label width is reserved by a "Copied" ghost.
- **Feedback:** **inline on every platform.** The icon swaps to a drawn check and the button label reads "Copied". On iOS and Android also `selectionClick`. A pointer tooltip ("Copy to clipboard") is optional extra, never the only feedback.
- **Motion:** icon swap: blur-fade at scale 0.8, in on `quick`, out on `quickExit`. The two overlap briefly. The check and × draw in on `fade`. Tracks: `CoilInputCopyTrack.fill`, `.mark`, `.action`, `.weight`, `.swap`, `.draw`.
- **Value font:** coil bundles no monospace font; the value is Inter with tabular figures and a slashed zero. Apps set `CoilInputCopyStyle.valueStyle` for a real mono.
- **Semantics:** a button named "Copy" plus the Field label (or `semanticLabel`); its value is the full text. It announces "Copied" or "Copy failed".
- **Keyboard:** Enter or Space copies.

### 14.3 Menus and overlays

#### Dialog

- **Anatomy:**
  - header: title (title role), description (body muted), gap 6, 16 below;
  - body;
  - footer: buttons trailing-aligned, gap 8, Cancel before primary;
  - an optional close button (ghost icon-only, 12 from the top and trailing edges).
- **Sizes:** max width `sm` 400 / `lg` 540 / `xl` 880; width = window − 32 up to the max; padding 24; container radius; surface level + 4.
- **Presentation:**
  - Pointer and tablets: centered.
  - **Phone (touch, < 600):**
    - A dialog becomes a **sheet** (§13.3) **only when it contains a form**: the title becomes the sheet title, and the footer becomes the action bar, stacked full-width with the primary on top and Cancel below. `lg` / `xl` forms open at the large detent.
    - **Short confirmations stay centered** (title + a sentence + buttons), the default for dialogs without a form.
    - A dialog shown as a sheet is **always drag-to-dismiss** (`stupid_simple_sheet`'s drag) unless the dialog is non-dismissible, in which case the drag, scrim tap and back are all off.
- **Motion:** scrim on `fade`; panel blur-fade with scale 0.97 → 1 on `gentle`, out on `gentleExit`.
- **Keyboard:** focus is trapped and starts on the first field (or the primary for confirmations). Esc closes. Focus returns to the trigger.
- **Semantics:** a modal route, `scopesRoute`, title as the route name.
- **Do:** use it for decisions that block the flow.
- **Don't:** nest dialogs; open a dialog from a sheet on a phone (push inside the sheet instead).

#### Tooltip

- **Anatomy:** an inverted bubble (`foreground` fill, caption text in `background`), padding 8×4 (~24 high), item radius, 8 from the trigger.
- **Pointer:**
  - opens after 200 ms of hover, or immediately on keyboard focus;
  - closes on leave, blur, Esc or pointer-down;
  - within 300 ms of another closing, it opens without delay;
  - **TooltipGroup:** one bubble glides between adjacent triggers on `quick`, morphing its width and crossfading the label on `fade`.
- **Touch:**
  - Android: long-press on icon-only buttons shows it above the finger (8 + 24), held while pressed and faded on release. It never fires the button.
  - iOS: none by default.
  - If the element has a context menu, long-press opens the menu instead.
- **Motion:** blur-fade + a 4 px slide toward the trigger on `quick`, out on `quickExit`.
- **Semantics:** the text is also `Semantics(tooltip:)`.
- **Don't:** put required information in a tooltip; tooltip a labeled button.

#### Dropdown (action menu; +sub, +search)

- **Anatomy:** popup (§13.2) → rows (§13.1) with optional leading icon, label, trailing shortcut caps (pointer) or chevron (submenu); group labels (caption muted, padding 8 / 6); separators (1 px `border` 60 % edge to edge); checkable rows (check or radio dot, trailing); destructive rows (`redLabel`, last, after a separator); empty state (muted, centered, padding 24).
- **Sizes:** rows per §13.1. Default width 288 (pointer), `max(trigger, 220)` (touch). Submenu width 224.
- **States:** the pointer highlight glides; checked rows are semibold with a check; the single-choice selected fill glides on `standard`; disabled rows are skipped.
- **Submenus:**
  - Pointer: open on hover after 100 ms with a safe triangle, or on Right / Enter. Placed 2 px from the parent, with the first row level with the trigger row. Left or Esc closes one level.
  - **Touch: tap to drill.** In a touch popover the submenu *replaces* the parent in place, with a "‹ Parent" back row; the panel height springs and the page slides on `standard`. In a sheet it's the same push.
- **Search** (`DropdownSearch`): a field band one row high at the top with a hairline below. Typing filters by word prefix, and printable keys typed into the list go to the field. Pointer: autofocused. Touch sheet: not autofocused.
- **Presentation:** §9.1. ≤ 8 items, no search and ≤ 1 submenu level stay anchored on phones.
- **Motion:** popup blur-fade on the tier's popover tokens (§7.2); highlight `quick`; sub push `standard`.
- **Keyboard:** arrows loop and skip disabled rows; Home and End; typeahead; Enter or Space activates; Esc closes one level; Tab closes all. Activating closes the menu after `acknowledgeDuration` for checkable rows, and immediately for actions.
- **Semantics:** menu, menuItem / menuItemCheckbox / menuItemRadio, `expanded` on the trigger.
- **Haptic:** iOS `selectionClick` on a pick in a sheet.
- **Do:** keep it to ≤ 12 items and ≤ 1 submenu level.
- **Don't:** put form inputs inside menus; nest more than 2 levels.

#### Select / MultiSelect (built)

- **Trigger:** like Input (hairline, `controlHeight`, `controlPaddingX`, min width 160) → [icon] value (placeholder muted) → chevron (muted → foreground on hover). Hover is the `hover` fill. While open it holds the `active` fill.
- **List:** popup rows; a trailing check; selected `active` fill in popovers; check only in sheets; multi-select uses merged blocks plus checks.
- **Presentation:** pointer popover (max height 300); phone ≤ 8 options touch popover; > 8 options or multi → sheet with the field label as its title. Lists over 12 options add a search row.
- **Motion:** the check draws on `fade`; a pick holds `acknowledgeDuration` (300 ms), then closes; the selected fill glides `standard`.
- **Keyboard:** the trigger opens on Enter, Space, Up or Down (the list starts on the picked row with the ring). The list has arrows, Home/End, PageUp/PageDown, typeahead, Enter/Space to pick, and Esc/Tab to dismiss. Focus returns to the trigger.
- **Semantics:** the trigger is a button with `expanded` and its value; the list is a menu; rows are `selected`.
- **Don't:** use it for fewer than 3 options (use a RadioGroup or Tabs) or for actions (use Dropdown).

#### ContextMenu

- **The Dropdown, opened at a point.**
- **Triggers:** right-click; Ctrl-click (macOS); Shift+F10 / Menu key (at the focused element); **long-press 500 ms on touch**.
- **Touch:** the pressed element lifts (scale 1.02 and shadow +1 on `quick`) with a haptic (§8.6). The menu anchors at the touch point as a touch popover (≤ 8 items), else a sheet.
- **Don't:** use the iOS preview-blur; put the only path to an action in a context menu (also offer a visible ⋯ button).

#### Combobox

- **Anatomy:** an input (field role) with an optional clear button and chevron; a list below (§13.2) with match highlighting (semibold on the matched prefix); an optional "Create '…'" row last; an empty state.
- **Multi:** chips wrap inside the field before the input. A chip is 24 / 20 / 28 / 24 high, padding 8, caption, `hover` fill, item radius (pill → full). Its remove × is 16 visual with the hit box growing to the chip height (44 on touch). The field height springs on `quick` as chips wrap.
- **Pointer:** the list anchors under the input, at least the input's width, max height 300; the input keeps focus.
- **Phone:** a **full-height sheet**. The input is on top, focused, with the keyboard up. Chips sit above the input, results below, and Done in the header for multi.
- **Motion:** chips enter scale 0.9 → 1 + fade on `quick` (growing from the leading edge) and exit on `quickExit`; siblings slide on `standard`; the list blur-fades on the tier's popover tokens (§7.2).
- **Keyboard:** typing filters and the active item resets to the first match; Up and Down move the active item; Enter picks it (IME-safe); Esc clears, then closes; Backspace on an empty input removes the last chip; Left and Right move between chips.
- **Semantics:** a combobox textField with `expanded`; rows `selected`; a live result count; the chip toolbar is labeled "Selected".
- **Do:** use it for long or open-ended option sets.
- **Don't:** autocomplete inline over the user's typing.

#### CommandMenu

- **Anatomy:** a search field (subtitle role, 48 high pointer, 52 touch); groups with caption headings; rows (§13.1) with icon, label and trailing shortcut caps; an empty state; a footer with key hints (pointer).
- **Pointer:** a dialog (size `lg`) placed at the top, `max(12 % of height, 50 % − 220)`, max height `min(440, 76 %)`. Opened with ⌘K / Ctrl+K through `Shortcuts`.
- **Touch phone:** a **full-height sheet**. The field is focused (the keyboard is the point). No shortcut caps, no footer. The soft keyboard's Search key runs the active row. The app must provide a visible entry point, since there's no shortcut.
- **iPad with keyboard:** the dialog, with ⌘ caps.
- **Filtering:** per-word prefix/substring matching (not fuzzy); groups with no hits hide.
- **Motion:** the panel height springs to the result height on `standard`; the highlight on `quick`; keyboard moves scroll the row to the center on `quick`.
- **Keyboard:** Up and Down wrap and skip disabled rows; Enter runs; Esc clears, then closes.
- **Semantics:** a combobox with a live result count.

### 14.4 Layout and display

#### Accordion (built)

- **Anatomy:** items, each a trigger row (label + chevron, trailing) and a collapsible panel (body muted, padding `controlPaddingX` sideways, 12 below). In `group` mode the items share one hover highlight and expanded items get a `hover` tint behind trigger and panel.
- **Sizes:** trigger = §13.1 one-line row; default width 288 (`group`) or full.
- **States:** the label is muted (pointer) or foreground (touch) at rest, foreground when open or hovered, and semibold when open. The chevron rotates 0 → 90° (RTL: 0 → −90°) with icon weight 533 when lit.
- **Modes:** `single` (with `collapsible`) and `multiple`.
- **Motion:** chevron on `quick`; panel height factor on `standard` with opacity on `fade` / `fadeExit`; tint on `fade`.
- **Keyboard:** each trigger is a tab stop; Enter or Space toggles; Up and Down move between triggers in a group.
- **Semantics:** button with `expanded`, and the panel is labelled by its trigger.
- **Touch:** press fill only.

#### Card (built)

- **Anatomy:** a container (surface 3 in light, 2 + hairline in dark; container radius) → [media] header (title role, description caption muted) → content → footer (actions); an optional dismiss ✕; an optional stretched action (the whole card is a link or button).
- **Variants:** `stacked` (media on top, full-bleed 16:9 image) and `inline` (media leading: a 32 tinted tile or an image 160 square).
- **Padding:** 16 (compact 12). Content and footer 12 below the header.
- **Groups:** one divided block with hairlines between cards, or `separated` (gap 8).
- **States:** a card with an action hovers (pointer) with the gliding highlight across a card grid; pressed `active` (touch); keyboard focus draws an inset ring.
- **Dismiss ✕:** pointer shows it on hover or focus-within; **touch always shows it**, 44 hit.
- **Card buttons:** small ghost buttons (28 pointer, 36 / 44 hit touch), caption semibold.
- **Motion:** highlight `quick`; dismiss exit is a blur-fade plus a height collapse on `standard`.
- **Do:** one primary action per card.
- **Don't:** nest cards.

#### Table (built)

- **Anatomy:** a header row (semibold, caption muted on pointer); body rows (cells muted, foreground when the row is lit or selected); hairline cell rules (`border`); an optional empty state that holds N rows of height.
- **Sizes:** cell padding `controlPaddingX` × vertical pad: rows 36 / 28 / 44 / 36.
- **States:** the row highlight glides (pointer); selected rows merge (§8.4); press fill on touch. A header cell that sorts is pressable.
- **Overflow:** scrolls horizontally inside a ScrollArea, with its edge fades where columns are hidden. A fade, not a shadow: it is the same signal every coil scroll region uses.
- **Pinned first column:** not built yet. It needs a two-dimensional viewport; the plan is `two_dimensional_scrollables`' `TableView` with `pinnedColumnCount: 1`, shared with the DataTable.
- **Motion:** highlight `quick`; selection `standard`.
- **Keyboard:** Tab to the table; arrows move the active row (and cell in interactive tables); Space selects; Enter opens.
- **Semantics:** table / row / cell roles with column headers.
- **Don't:** zebra stripes.

#### Banner (built)

- **Anatomy:** [status icon, one title line tall] title (body semibold) + description (body muted) → actions (Buttons, compact) → [dismiss ✕]. An optional tinted variant (status hue 8 % background).
- **Sizes:** padding 16 (compact 12; touch 16 with a 44 ✕ hit); icon 20 / 16 / 20; gap 12.
- **Placement:** `inline` (in flow) or `fixed` (top of the viewport, under the safe area).
- **Motion:**
  - Appear: the row height opens on `standard`; then the banner fades and scales 0.4 → 1 from the top on `gentle`, 80 ms later.
  - Dismiss: reverse on the exit tokens.
  - Touch: swipe horizontally to dismiss (with velocity).
  - Reduced motion: fade only.
- **Semantics:** a live region (polite; assertive for destructive); the ✕ is labeled "Dismiss".
- **Don't:** stack more than 2; use it for transient confirmations (use inline feedback).

#### Breadcrumb (built)

- **Anatomy:** a single row of crumbs (body, muted; the current page foreground, not a link). Each crumb ends in a chevron separator (14, muted). "…" opens a menu of the hidden crumbs. A sibling picker on a crumb waits for the Dropdown component.
- **Sizes:** crumb height `controlHeight` (28 on pointer compact by default; 44 hit on touch), padding 6.
- **Collapse:** when the row overflows, the middle crumbs collapse into "…". On phones only the first, "…" and the last two show. The full names of truncated crumbs are reachable in the "…" menu, not only in a tooltip.
- **Motion:** the highlight glides across crumbs on `quick` (pointer).
- **Keyboard:** native Tab order; Enter follows or opens.
- **Semantics:** navigation, labeled "Breadcrumb"; the current page has `selected`.

#### ThinkingSteps / ThinkingIndicator (built)

- **ThinkingSteps:**
  - Anatomy: a collapsible trigger ("Thought for 12s", body semibold when open, chevron) → a list of steps. A step is [icon or a 6 dot] title (body) → detail (caption muted) → sources (small solid badges, gap 6; a private badge until the Badge component lands) → an image (max 200 wide).
  - Width 320, max full.
  - Motion: collapse on `standard`; each new step grows its height on `gentle` and fades in after 80 ms; source badges scale 0.85 → 1 on `standard` with a 4 → 0 blur.
- **ThinkingIndicator:**
  - Anatomy: [glyph 20 / 18, muted] label (body muted). The width is reserved by the longest word.
  - Motion: the word cycles every 4 s; the incoming word rises 80 % → 0 and fades on `standard`, the outgoing word rises out on `standardExit`. The words are a parameter. Reduced motion: crossfade only, every 4 s.
  - Semantics: a live region (polite), announced once per change at most every 4 s.

#### CarouselDots (built)

- **Anatomy:** a row of 6 dots 12 apart. The current dot is a 24 pill, either solid or filling with progress. Track `foreground` 15 %, fill 40 %.
- **Pointer:** each dot has its own 18 round click target; the highlight glides across dots. For screen readers the row is still one adjustable control.
- **Touch:** the group is **one adjustable control**, 44 high. Tap or drag along it to scrub; swipe the carousel itself to page. Single dots don't get 44 boxes.
- **Motion:** pill width 6 ↔ 24 on `standard`; fill driven by progress. The dots never advance by themselves: autoplay belongs to the carousel that owns them, which stops it under reduced motion.
- **Semantics:** adjustable, "Slide 2 of 5".

#### ChatMessage (built)

- **Anatomy:** attachments (FileThumbnails 80, gap 6, aligned to the sender's side) → bubble → meta row (time caption muted and actions as icon-only ghost buttons, gap 2).
- **Sizes:** max width 80 %; text is subtitle role; bubble padding 14×8 (compact 12×6; touch 16×10).
- **Variants:**
  - user: a bubble in `accent` mixed 45 % into background (Oklab), container radius, aligned to the end;
  - assistant: no bubble, full width, aligned to the start.
- **Meta row:** pointer shows it on hover or focus within the message; **touch always shows it**. Long-press on touch opens a context menu (Copy, Retry…).
- **Motion:** enter fade + rise 8 + scale 0.96 → 1 on `standard`, from the sender's bottom corner; earlier messages slide to make room on `standard`.
- **Semantics:** each message is a container labeled with sender and time.

#### ScrollArea (built)

- **Physics:** platform physics (§9.2).
- **Edge fades (`CoilScrollEdgeFade`):** each edge fades in as content scrolls away from it, up to 32, following the scroll direction (RTL, reversed lists). The amount springs on `fade`. The ramp is eased, not linear, so it has no visible start or end. Over a known solid background the fade is painted in that color on top; elsewhere it masks the content, which costs an offscreen layer.
- **Pointer scrollbar:** 4 wide, widening to 6 on hover; 2 from the edge and 4 from the ends; `foreground` 8 % (12 % hovered, 16 % dragging); radius full. It shows while scrolling or hovered and hides 600 ms later. The hide is `RawScrollbar`'s timed fade over the `fade` token's duration, not a spring: `RawScrollbar` owns that animation and exposes no way to drive it.
- **Touch:** a thin overlay bar in coil's colors (3 wide) that shows only while scrolling and can't be grabbed. Flutter draws no OS scrollbar, so this stands in for it.
- **Keyboard:** the viewport is focusable when it scrolls; arrows, Page and Home/End scroll; the focus ring is inset 1.
- **Don't:** nest scroll areas on the same axis.

### 14.5 Shell and composites

#### Sidebar

- **Anatomy:**
  - header (workspace switcher);
  - content: groups, each a caption label (32 row, optionally a collapsible toggle), menu rows, and sub-menus (indented 12, rows 28);
  - footer (user);
  - rail (pointer only, 8 grab strip);
  - an inset main area.
- **Sizes:**
  - width 256 (resizable 160–360 on pointer; collapses when dragged 56 past the minimum);
  - rows 32 / 28 / 44 / 36, padding 8, icon 16 / 14 / 20 / 16;
  - trailing badge 24, actions 24 each (gap 4).
- **Variants:** `sidebar` (flush column with an edge hairline), `floating` (surface card inset 8), `inset` (flush rows; the main area becomes a raised card with an 8 margin).
- **States:** rows are muted → foreground when lit; **active row** `active` fill with semibold (ghost width), its own glide per level; hover glides across all levels; disabled 50 %.
- **Row actions:** pointer shows them on hover, focus or while their menu is open; **touch always shows them**, 44 hit.
- **Pointer behavior:** `[` / `]` or ⌘B toggles it; the open/close width and offset run on `gentle` / `gentleExit`; dragging the rail tracks 1:1; peek (hover the collapsed edge 150 ms, or click) shows a floating card on `standard`.
- **Touch, < 768:** a **modal drawer** `min(320, 85 % width)` from the leading edge on `standard` (no bounce), with a 40 % scrim.
  - Dragging it closed follows the finger and releases with velocity.
  - It **closes on navigation**, and system back closes it.
  - No edge-swipe open by default (opt-in on root routes only, outside `systemGestureInsets`).
- **Keyboard:** roving within each menu; Up and Down; Right and Left expand and collapse groups; Enter navigates; the ring travels.
- **Semantics:** navigation; the active row is `selected`; groups are `expanded`.

#### Calendar

- **Anatomy:**
  - caption: "‹ November 2026 ›" (title role) with the month/year label opening a jump grid;
  - weekday row (caption muted, locale first day);
  - a 6 × 7 day grid (body, tabular), **always 6 rows** so the height never jumps.
- **Cell sizes:** 36 / 32 / 44 / 40.
- **Day states:**
  - outside the month: muted 60 %;
  - today: semibold with a 4 `brand` dot;
  - selected: `foreground` fill with `background` text;
  - range: an `active` band per week row (merged-selection block, rounded at the ends) with the endpoints filled;
  - disabled: 40 % and struck through for "booked";
  - hover (pointer): the gliding highlight; in range picking, the highlight *is* the proposed end.
- **Months:** pointer and tablets show 2 side by side when they fit; phones show 1.
- **Motion:** month change slides the grid by ⅓ of the stride with a crossfade on `standard`; on touch, **horizontal paging follows the finger and keeps the fling velocity**; highlight `quick`; range band `standard`.
- **Keyboard:** arrows move the day; PageUp/PageDown change the month; Shift+PageUp/PageDown change the year; Home and End go to the week's start and end; Enter selects.
- **Semantics:** grid cells carry full-date labels; previous and next month are semantics actions.

#### DatePicker

- **Trigger:** like a Select trigger: [calendar icon] label ("Wed Nov 13", "Nov 13 – 15", placeholder muted), plus an optional clear ×. Width is stable: reserved for the widest label in the locale.
- **Pointer / tablet:** a popover with Calendar; presets in a 152 column on the leading side (below when narrow); time fields as compact Combobox inputs (typed, 15-minute list).
- **Phone (touch, < 600): a sheet built for the thumb.**
  - Grabber → caption row (title role; the ▾ opens the month/year grid) → one month, 44 cells, **horizontal paging**, fixed 6 rows.
  - Presets: a horizontally scrolling chip row (Today, Tomorrow, Next week…).
  - Time: chips ("Start 11:00", "End 12:45"). Tapping one pushes the **time page** inside the sheet on `standard`, with a "‹ Date" back row.
    - The time page is **two snap columns** (hours | minutes in the minute step), flat 44 rows. A selection band in `active` sits across the center, the center row is foreground semibold and the others are muted.
    - The columns snap on `standard` with the fling velocity. No 3D wheel.
    - A duration caption ("1 h 45 min") sits under the end column. "Type a time" opens a numeric field (opt-in).
  - Footer: Clear (ghost) and **Done** (primary) in range and time modes. A single date commits on tap and closes after 200 ms.
- **Keyboard:** as Calendar. Esc restores the previous range. Hardware keyboards on iPad get the typed time field.
- **Semantics:** the snap columns are adjustable (VoiceOver swipe up/down changes the hour).
- **Scope:** v1 includes date, range, presets and time. The time page can land one milestone after the grid. A drag-to-select range is later.

#### InputMessage (chat composer)

- **Anatomy:** a container (hairline, container radius, padding 8) → attachment tray (FileThumbnail 80 tiles, each with a 20 × badge with a 32 / 44 hit) → queue rows (32 / 28 / 44, muted, reorderable) → textarea (subtitle role, 1–10 lines) → toolbar (attach, model, trailing **send button**).
- **Send button:** icon-only primary, 28 / 24 / 36 (44 hit). It morphs **send ↔ stop ↔ queue**, swapping the glyph with the blur-fade on `quick`.
- **Behavior:**
  - **Hardware keyboard:** Enter sends, Shift+Enter makes a newline, ↑ in an empty field recalls history.
  - **Touch:** Return inserts a newline; Send is the button.
  - Suggestions: chips above the field (touch: above the keyboard).
- **States:** focus (container border foreground 40 %), drag-over (`brand` 30 % dashed border), disabled, streaming.
- **Motion:** tray, queue and suggestion regions open with height on `standard` and opacity on `fade`; tiles scale 0.9 → 1 on `quick` and siblings slide on `standard`; queue rows reorder on `standard`.
- **Touch:** the tile × and queue × are always visible; swipe a queue row to delete.
- **Semantics:** textField multiline, labeled "Message"; send is a button whose label follows its mode.

#### FileThumbnail

- **Anatomy:** a square preview (`size` required), radius item (or nested), `muted` background.
- **States:**
  - pending: spinner 24, muted;
  - image: cover-fit;
  - PDF: page 1 via a pluggable renderer;
  - failed or unsupported: a document glyph at 35 % of the size (min 16), muted.
- **Motion:** none of its own; the image fades in on `fade`.
- **Semantics:** an image labeled with the file name; the spinner announces "Loading preview".

#### DataTable (reduced v1)

- **v1 scope:**
  - a headless controller (sort, search, column filters, visibility, pagination, selection);
  - the grid (Table look, rows 36 / 28 / 44 / 36);
  - a select column (checkboxes always visible);
  - a sortable header menu (Sort ascending/descending, Clear, Hide);
  - row actions (a trailing ⋯ ghost button, 28 / 44 hit) and the same items as a context menu;
  - search (a ghost icon button that springs open to a 224 field on `standard`);
  - pagination (compact buttons, 44 hit on touch);
  - the full row keyboard model;
  - skeleton and empty states;
  - a pinned first column.
- **Deferred (v2):** typed filter chips, inline editors, column reorder and resize, sub-rows, the selection command bar, layout FLIP.
- **States:** the row highlight glides (pointer); selection merges (§8.4); press fill (touch).
- **Touch:**
  - rows 44, cell padding 16, the sticky first column with an edge shadow once scrolled;
  - no resize or move handles;
  - header menus anchored;
  - row actions on long-press plus the visible ⋯;
  - an optional `mobileLayout: cards` below 600 (label : value pairs);
  - selection shows a bottom action bar above the safe area.
- **Keyboard:** arrows move the active row; Space selects; Shift+arrows extend; Enter opens; ⌘A / Ctrl+A selects all; Esc clears the selection; Shift+F10 opens row actions.
- **Semantics:** table roles, the header with sort state, rows `selected`.
- **Title:** display role, aligned past the select column.

#### AskUserQuestions

- **What it is:** an assistant's questions, one at a time, in a card. A question takes one option (picking it moves on), several options (then Continue), or typed text.
- **Anatomy:** a hairline card (surface 3 light, 2 dark; container radius; max width 520) → "Question 2 of 4" (caption muted) → the question (title role) → option rows, an optional typed "other" row last, or a text field → footer: Back (ghost) at the start; Skip (ghost) and Continue or Finish (primary) at the end. Footer buttons are compact.
- **Geometry:** rows are inset `popupInset` from the card edge, like a popover, so card radius = item radius + inset. Text starts at `popupInset + controlPaddingX`, and the step line, the question and Back's label all align with it.
- **Rows:** §13.1 heights (36 / 28 / 44 / 36), padding `controlPaddingX`. The label is foreground at rest (a question's options are content, not a menu) and semibold with a ghost width when picked. A description follows inline in muted body, or sits under the label in caption (`layout: stacked`).
- **Number keys (pointer only):** each row ends with its number (11/14 micro), or starts with it (`keyPosition: start`). Single choice: a plain number, foreground when picked. Multiple choice: the number in a 20 box (18 compact) with a hairline, filled `foreground` when picked. A lit single-choice row swaps its key for a submit arrow: a `foreground` block 8 larger than the key with a chevron, in on `quick`, out on `quickExit`.
- **States:** the gliding highlight lights rows; picked rows, and the "other" row once it has text, merge into one `active` block (§8.4); one focus ring travels between rows. The "other" field is quiet at rest; while focused and empty it shows a surface fill and a hairline. A rejected free-text answer shows its message under the field (caption `destructive`, live region) and the field turns invalid.
- **Touch:** no number keys and no submit arrow. Rows are 44, rest at full foreground, and show the press fill under a finger. A picked multiple-choice row shows a trailing check instead of a filled key. A tap never pulls focus, so the keyboard stays down until the user taps a field.
- **Motion** (tracks `CoilAskUserQuestionsTrack.height`, `.step`, `.selection`, `.ring`, `.label`, `.hint`, `.press`, `.buttons`): between questions the card's height springs on `standard` while the old question fades out on `fadeExit` (clipped as the card shrinks) and the new one fades in on `fade`. Footer buttons appear and leave with a fade and scale 0.85 on `quick`, and their neighbors slide. Merge/split on `standard`, highlight and ring on `quick`, label weight and key colors on `fade`.
- **Keyboard:** works while focus is in the card. 1 to 9 pick the row with that number; the number after the options focuses the "other" field. Up and Down move between rows with wrapping and don't pick. Enter or Space picks or toggles the focused row. Ctrl+Enter (⌘+Enter on Apple platforms) continues. Escape or the arrow pointing back returns; the arrow pointing forward skips (both flip in RTL). In a text field, digits and arrows edit text, Enter answers, and Shift+Enter is a newline in a multi-line field (touch: Return is a newline and Continue answers). Up and Down in the one-line "other" field return to the rows. When a question changes and focus was in the card, focus moves to the new question's picked row, its first row, or its field.
- **Semantics:** the step line is a live region, so each new question is announced. The question is a header. A single-choice question is a radio group labelled by the question, with radio rows; a multiple-choice one is a group of checked rows. Each row reads its label and description. Keys and the arrow are excluded.
- **API:** `CoilAskUserQuestions<T>(questions:, controller:, onCompleted:, onSkipped:)`. Questions are `CoilQuestion.single`, `.multiple` and `.freeText`; answers are `CoilAnswer<T>` (values, text, skipped) keyed by question id in a `CoilAskUserQuestionsController`.
- **Not ported from the web:** the document-wide digit listener (coil scopes keys to the card's focus; pass `autofocus`); the footer's ← and → and ⌘↵ key caps (coil has no key-cap primitive); a growing multi-line "other" field (it is one line, so the keyboard's action button can submit it).
- **Do:** keep it to a few short questions.
- **Don't:** use it for a form the user fills at their own pace (use Field); put more than 9 options in a question (keys stop at 9).

---

## 15. Out of scope

- **Out entirely:** NavItem / NavMenu (Sidebar covers it), and the docs-site libraries.
- **Deferred:**
  - ColorPicker, Reveal, QueuedStack and the settings-dialog block;
  - Slider range / steps / tooltip mode (v1.x);
  - Calendar's 2-month strip animation and stacked layout;
  - DataTable v2;
  - PDF thumbnails beyond the renderer hook.

## 16. Review checklist

A component is done when:

1. Its labels pass the ink-centering test (±0.5) at every tier and text scale.
2. Its goldens exist for pointer and touch, light and dark, text scales 1 / 1.5 / 2, RTL and high contrast.
3. `expectCoilPattern` passes for semantics, keyboard and focus.
4. All of its motion goes through tokens, and reduced motion is honored.
5. No sticky hover after a tap, and no ring after a click (`touch_vs_mouse` test).
6. Shapes are superellipses, and nested radii are concentric.
7. It follows this document, or this document is updated in the same change.

## 17. Decisions

The user's decisions on the former open questions (2026-11-13):

1. **Touch radii:** item 10, popover and sheet 16, focus ring 12. `CoilShape` resolves per tier; pointer values are unchanged (§5).
2. **One row height:** 44 visual everywhere, Android included. There is no 48 px Android hit box: Flutter has no hit slop, and growing the hit area without changing layout would need a custom hit-test override, the kind of workaround coil avoids (§4.2, §9.2, §10).
3. **The check in sheets and menus** stays the text color (`foreground`) (§13.1).
4. **Sheet header hairline:** only while content scrolls beneath the header (§13.3).
5. **Dialogs on phones** become a sheet only when they contain a form; short confirmations stay centered. A dialog shown as a sheet is always drag-to-dismiss, unless it's non-dismissible (§14.3 Dialog).
