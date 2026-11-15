# Sidebar

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/sidebar.dart';
```

Exports `CoilSidebar`, `CoilSidebarAction`, `CoilSidebarActionsVisibility`, `CoilSidebarBar`, `CoilSidebarCalloutExpand`, `CoilSidebarCalloutStack`, `CoilSidebarCollapsible`, `CoilSidebarController`, `CoilSidebarDot`, `CoilSidebarDotStyle`, `CoilSidebarGroup`, `CoilSidebarItem`, `CoilSidebarMenu`, `CoilSidebarMenuFocus`, `CoilSidebarPeek`, `CoilSidebarRail`, `CoilSidebarScaffold`, `CoilSidebarSeparator`, `CoilSidebarSide`, `CoilSidebarStatus`, `CoilSidebarStyle`, `CoilSidebarTrack`, `CoilSidebarTrigger`, `CoilSidebarVariant`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject sidebar` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Sidebar

- **Anatomy:**
  - a scaffold holding the sidebar and the page (`body`);
  - the panel: header, scrolling content, footer;
  - groups: a caption label (32 row; a toggle with a chevron when collapsible) with 1–3 actions, then menu rows;
  - menu rows, two levels deep (sub-rows indented so their labels line up with the parent's, rows 28);
  - callouts in the footer, one card or a stacked pile;
  - the trigger (a ghost icon button in the page) and the rail (pointer only, an 8 grab strip on the inner edge).
- **Sizes:**
  - width 256, resizable 160–360 by the rail; dragging 56 past the minimum folds it;
  - rows 32 / 28 / 44 / 36, padding 8, icon 16 / 14 / 20 / 16;
  - **one 24 rhythm:** every action, badge and chevron is a 24 box (16 icon, gap 4), its center 26 from the inner edge, from header to footer; touch hit 44;
  - the phone drawer `min(320, 85 % width)`.
- **Variants:** `sidebar` (a flush column with an edge hairline), `floating` (a surface card inset 8), `inset` (flush rows; the page becomes a raised card with an 8 margin that gives way on the sidebar's side as it opens).
- **Side:** `start` or `end`, following the text direction. The rail, the drawer, the peek edge and the default key follow it.
- **Folding:** `offcanvas` slides it off the edge and gives the page its width back; `none` is a static column (no rail, shortcut or drawer), as in the settings dialog. **There is no icon-only rail on purpose:** glyphs alone turn navigation into a quiz, and section labels and actions have nowhere to go. Peek brings the real sidebar back instead.
- **Header and footer:** stack parts vertically (each on its own row, actions as menu rows) or horizontally (`CoilSidebarBar`: the primary part, then 1–3 icon actions on the 24 rhythm).
- **Callouts:** a pile of cards, front first. At rest up to 2 peek 12 behind the front, each 5 % smaller. Inline cards fan out into a list under a hovering mouse (or keyboard focus); banners never fan. Dismissing the front promotes the next on `standard`. Touch never fans.
- **States:** rows are muted → foreground when lit; the active row has the `active` fill with semibold (ghost width), its own glide per level; hover glides across all levels; disabled 50 %. A group label raises its contrast on hover and reveals its chevron; a folded group keeps the chevron. On touch the chevron always shows.
- **Row actions:** menu entries (an action, or a submenu such as the overflow ⋯). Pointer shows them as 24 icon buttons on hover, focus or while their menu is open, and the label claims their width only then; a right-click opens all of them as a context menu. **Touch shows only the last one** (the ⋯, rightmost by convention; a lone action shows as is), 44 hit, and a long-press opens all of them as a context menu with the haptic lift, as DataTable does, so the label keeps its width at large text.
- **Pointer behavior:**
  - `[` (`]` for a sidebar on the right) or ⌘B / Ctrl+B toggles it while focus is inside the scaffold; the innermost scaffold answers; never while typing in a field. With nothing focused (at launch), the outermost scaffold takes focus, so the key works at once. The scaffold is a focus scope, so focus a folding sidebar drops stays inside and the next press still works.
  - Opening and closing run on `gentle` / `gentleExit`. A rail drag sets the width 1:1; a fold or reopen during the drag springs on `standard`, and once it lands the drag tracks 1:1 again. The space taken is the width times how open it is, two separate tracks.
  - Peek: hovering the folded edge (or the folded trigger) 150 ms, or clicking the edge, floats the sidebar out as a card over the page on `standard`. It holds while the pointer is within 8 of the card (a tooltip or menu over it doesn't count as leaving) and lets go 250 ms after it leaves; Escape or a press elsewhere dismisses it. Peeking never pins it open.
- **Touch, < 768 (the scaffold's width):** a **modal drawer** from the sidebar's edge on `standard` / `standardExit`, with a 40 % scrim.
  - It stays a descendant of the scaffold (not a route), so it always shows the app's current state.
  - Dragging it closed follows the finger and releases with velocity: a fling decides by direction, a slow release by position.
  - It **closes on navigation** (a row pick), on the scrim, Escape and system back.
  - Focus moves into it and returns on close.
  - No edge-swipe open by default.
- **Persistence:** `CoilSidebarController` holds `open` and `width`. The app saves them and restores them by creating the controller; coil stores nothing. The drawer and peeks never change `open`.
- **Keyboard:** roving within each menu; Up and Down; Right and Left expand and collapse sub-trees; Enter navigates; the ring travels. Group labels are tab stops that Enter or Space folds. A folded sidebar leaves the focus order.
- **Semantics:** a navigation landmark when the sidebar has a label (each needs its own); the active row is `selected`; collapsible labels are buttons with `expanded`; the rail offers increase, decrease and tap; the drawer is a named route scope.
