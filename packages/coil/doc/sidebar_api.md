# Sidebar API

coil's sidebar covers FF's whole surface: three layouts, either side
(or both, nested), resizing, peeking, a phone drawer revealed from behind
the page, two levels of rows with actions and badges, callouts, and a
settings dialog. The shell is composition with
`Widget` slots. Menu rows are data entries with widget slots, like
`CoilMenuEntry`, so one hover fill and one keyboard list span both levels.
This note maps each FF part and prop to coil.

**Text is a `Widget`.** Labels, captions and tooltips take a `Widget`,
usually a `Text`, styled through `DefaultTextStyle` and `IconTheme`. Where
coil needs a string (semantics, the settings dialog's select), there is a
separate `semanticLabel`. Null falls back to the text of a `Text` or
`RichText`; any other widget must pass it.

## Shape at a glance

```dart
final sidebar = CoilSidebarController(open: prefs.open, width: prefs.width)
  ..addListener(() => prefs.save(sidebar.open, sidebar.width));

CoilSidebarScaffold(
  controller: sidebar,
  variant: .inset,
  peek: .hover,
  sidebar: CoilSidebar(
    semanticLabel: 'Main',
    header: CoilSidebarBar(
      primary: WorkspaceSwitcher(),
      actions: [
        CoilSidebarAction(
          icon: SearchIcon(),
          semanticLabel: 'Search',
          tooltip: Text('Search'),
          shortcut: SingleActivator(LogicalKeyboardKey.keyK, meta: true),
          onPressed: search,
        ),
      ],
    ),
    footer: UserMenu(),
    children: [
      CoilSidebarGroup(
        label: Text('Threads'),
        expanded: threadsOpen,
        onExpandedChanged: (open) => setState(() => threadsOpen = open),
        actions: [/* 1 to 3 CoilSidebarActions */],
        child: CoilSidebarMenu(items: [
          CoilSidebarItem(
            label: Text('Fix login'),
            status: .unread,
            trailing: Text('4'),
            actions: [/* up to 3 */],
            onPressed: () => open('login'),
          ),
          CoilSidebarItem(
            label: Text('Agents'),
            leading: BrainIcon(),
            expanded: agentsOpen,
            onExpandedChanged: (open) => setState(() => agentsOpen = open),
            children: [
              CoilSidebarItem(label: Text('Research'), onPressed: () {}),
            ],
          ),
        ]),
      ),
    ],
  ),
  body: Column(children: [
    CoilSidebarTrigger(icon: PanelIcon()),
    Expanded(child: page),
  ]),
)
```

## Shell: `SidebarProvider` + `Sidebar` → `CoilSidebarScaffold`

The scaffold owns state and layout, like `Scaffold` owns its drawer. FF's
`SidebarInset` is the `body:` slot.

| FF | coil | Notes |
|---|---|---|
| `open`, `onOpenChange`, `defaultOpen` | `controller: CoilSidebarController?` | A `ChangeNotifier` with `open`, `width` and `toggle()`. Null: the scaffold owns one, open and 256 wide. |
| `persist` (cookie) | none built in | The app listens to the controller, saves `open` and `width`, and restores them by creating the controller. Drawers and peeks never change `open`. |
| `width` | `CoilSidebarController.width` | The rail changes it. |
| `widthMobile` | `drawerWidth: double?` | Null is `min(320, 85 %)`, per DESIGN.md. |
| `mobileBreakpoint` 768 | `drawerBreakpoint: 768` | The scaffold's own width, so it works in a pane. |
| none | `drawerReveal: CoilDrawerReveal? { behind, over }` | Null: `behind` on the touch tier (the page slides aside), `over` on the pointer tier (a panel over the page, as in a narrow desktop window). |
| none | `drawerDrag: CoilDrawerDrag? { anywhere, close, none }` | Null: `anywhere` on touch, except a start-side drawer on a route iOS can swipe back (`close` there); `close` on the pointer tier. |
| `shortcut` | `shortcuts: Set<ShortcutActivator>?` | Null: `[` for a sidebar on the left, `]` on the right, and ⌘B / Ctrl+B. Empty disables them. Never while typing in a field. |
| focus-scoped key | `autofocus: true` | The scaffold is a focus scope and takes focus when nothing has it, so the key works from launch and keeps working after the sidebar folds. A nested scaffold never takes it, so the outermost one answers, as on the web; with focus inside, the innermost one does. |
| `peek` | `peek: CoilSidebarPeek { none, hover, click }` | |
| `side` | `side: CoilSidebarSide { start, end }` | Directional, so RTL mirrors it. The default key follows the physical edge. |
| `variant` | `variant: CoilSidebarVariant { sidebar, floating, inset }` | Inset draws `body` as a raised card. |
| `collapsible` | `collapsible: CoilSidebarCollapsible { offcanvas, none }` | **No icon rail**, on purpose. |
| `rail` | `rail: Widget? = const CoilSidebarRail()` | Null hides it. |
| `railTooltipOpen` | dropped | Only FF's docs use it. |
| `bordered` | `CoilSidebarStyle.edgeColor` | Transparent draws none. |
| 160–360, slop 56 | `minWidth`, `maxWidth`; `CoilSidebarRail.collapseSlop` | |
| motion | `motion:` + `motions: Map<CoilSidebarTrack<Object>, Motion>?` | Tracks: `fold` (how open, 0 to 1), `width`, `peek`, `drawer`, `highlight`, `selection`, `expand`, `callouts`. |

`CoilSidebarScaffold.of(context)` returns the controller.

**Rail** (`CoilSidebarRail`, pointer only): an 8 strip on the inner edge.
A drag resizes 1:1, dragging 56 past the minimum folds (pulling back before
release reopens), and a click folds. Its tooltip opens beside the strip
and follows the pointer: "**Drag** to resize", "**Click** to collapse" and
the key. Screen readers get increase, decrease and tap.

**Peek:** while folded, a 12 strip at the edge. `hover` floats the sidebar
out after 150 ms, and so does resting on the folded trigger; `click` does on
press. Escape or a press elsewhere dismisses it, and in hover mode leaving
it does after 250 ms. A tooltip or menu over the card doesn't count as
leaving. The peek card and the column hold the same sidebar (moved with a
`GlobalKey`), so it keeps its state.

**Drawer** (`CoilDrawer`, a primitive): below `drawerBreakpoint` the
sidebar becomes a panel of a `CoilDrawer` around the page. It stays a
descendant of the scaffold, not a route, so it always shows the app's
current state.

- **Reveal.** On touch the sidebar lies underneath and the page slides
  aside to reveal it (`CoilDrawerReveal.behind`). While it is away from the
  edges the page takes the device's screen corner radius, which
  `CoilScreenRadius` reads once from `corner_radius_plugin`, and it squares
  up the moment it covers the sidebar again. On the pointer tier the panel
  slides in over the page (`over`), as before.
- **Drag.** On touch a horizontal drag anywhere on the page opens it. The
  drag is read with `scroll_drag_detector`: a horizontal scrollable in the
  page scrolls first and hands over only when the drag *starts* at its edge
  (`ScrollDragMode.boundaryStart`), so flicking back through a carousel
  never yanks the drawer open. While open, drags on the page or the panel
  close it (`scrollFirst` inside the panel). Every drag follows the finger
  and releases into the spring with its velocity; a fling (400 px/s)
  decides by direction, a slow release by position.
- **Back swipe.** On iOS and macOS, when the route can be popped, the
  start-side drawer doesn't open by drag: that drag is the route's back
  swipe. It still closes by drag, the end side still opens, and the trigger
  always works. `drawerDrag: .anywhere` overrides this.
- **Look** lives in `CoilSidebarStyle`: `drawerCornerRadius` (null follows
  the screen), `drawerFallbackCornerRadius` (square), `drawerScale` (1),
  `drawerScrimColor` (the 20 % / 30 % barrier at 40 %), `drawerShadows` (step 8). The
  springs are the `drawer` track.
- **Closing and focus.** A press on the page, Escape, system back (a
  `LocalHistoryEntry`, like `Scaffold`), a drag and a pick in a menu close
  it. Focus moves into the panel and returns on close. The panel is a named
  route scope; the page is hidden from screen readers except for its
  dismiss action.

**Both sides.** Nest two scaffolds, a `start` one whose `body` is an `end`
one. Their drawers find each other: a drag the inner one can't use (toward
a side it has no panel on) moves the outer one, and opening either closes
the other, so a phone gets a left and a right sidebar that behave as one
drawer. `CoilSidebarTrigger(side: .start)` / `(side: .end)` reaches either
from the page, and `CoilSidebarScaffold.of` keeps returning the nearest.

```dart
CoilSidebarScaffold(
  sidebar: navigation,
  body: CoilSidebarScaffold(
    side: .end,
    sidebar: details,
    body: Column(children: [
      Row(children: [
        CoilSidebarTrigger(side: .start, icon: PanelLeftIcon()),
        const Spacer(),
        CoilSidebarTrigger(side: .end, icon: PanelRightIcon()),
      ]),
      Expanded(child: page),
    ]),
  ),
)
```

**`CoilSidebarTrigger`:** `icon`, `openLabel` / `closeLabel` widgets (with
optional semantic strings), and `side` to drive the nearest scaffold on
that side. A ghost icon button whose tooltip names the action and shows the
key; below the breakpoint it reads open while the drawer is.

## Panel: `SidebarHeader` / `SidebarContent` / `SidebarFooter` → `CoilSidebar`

`CoilSidebar({Widget? header, Widget? footer, required List<Widget> children, String? semanticLabel, CoilSidebarStyle? style})`.
`children` scroll with edge fades. With a `semanticLabel` the sidebar is a
navigation landmark; Flutter needs each landmark's label to be unique.

**Stacking** is composition: a `Column` of parts and menu rows for
vertical, `CoilSidebarBar({required Widget primary, List<Widget> actions})`
for horizontal.

**The 24 rhythm:** `CoilSidebarAction({required icon, required semanticLabel, required onPressed, Widget? tooltip, Widget? shortcut})`
is the one 24 icon button (16 icon, gap 4; 44 hit on touch) in bars, group
labels and rows. `shortcut` goes in the tooltip's shortcut slot, usually
a `CoilKbd`. A menu trigger passes no tooltip.

`SidebarSeparator` → `CoilSidebarSeparator`. `SidebarInput` → a compact
`CoilInput` with a `CoilKbd` trailing.

## Sections: `SidebarGroup*` → `CoilSidebarGroup`

`CoilSidebarGroup({Widget? label, String? semanticLabel, List<Widget> actions, bool expanded = true, ValueChanged<bool>? onExpandedChanged, required Widget child})`.
With `onExpandedChanged` the label is a disclosure: hover raises its
contrast and shows a chevron, which stays while folded and always shows on
touch. `actions` (1 to 3) always show. Controlled only.

## Rows: `SidebarMenu*` → `CoilSidebarMenu` + `CoilSidebarItem`

`CoilSidebarMenu({required items, focus: CoilSidebarMenuFocus { ring, highlight }, CoilSize? size, String unreadLabel, style, motion, motions})`.

| FF | `CoilSidebarItem` |
|---|---|
| children text | `label: Widget`, `semanticLabel: String?` |
| `icon` | `leading: Widget?`; its stroke thickens when lit |
| `status` | `status: CoilSidebarStatus? { active, unread, idle }`: a dot when there's no `leading`; `unread` is announced; `active` selects |
| `dot` | `leading: CoilSidebarDot(.filled / .ring)` |
| `isActive` | `selected` |
| `SidebarMenuBadge` | `trailing`, a 24 slot that keeps the last place |
| `SidebarMenuAction(s)` + `showOnHover` | `actions: List<CoilMenuEntry>` (up to 3: `CoilAction`s, or a `CoilSubmenu` for the ⋯) + `actionsVisibility: { hover, always }`. On pointer they are 24 icon buttons, shown while the row is hovered, keyboard-focused or holds focus (an open menu); the label claims their width only then. A right-click opens them all as a context menu. Touch shows only the last one and opens them all on long-press, as DataTable does. Entries, not widgets, so one list drives the buttons and the menu. |
| `SidebarMenuSub`, `SidebarMenuSubButton` | `children` + `expanded` + `onExpandedChanged`. One level only. A parent with no `onPressed` toggles on press. |
| `size: "lg"`, `variant: "outline"`, `render`/`asChild` | dropped: heights are minimums, and `label` takes any widget |
| `SidebarMenuSkeleton` | wrap skeleton rows in `CoilSkeletonRegion` |

**Keyboard:** Up and Down rove the visible rows of both levels, Home and
End jump, Right opens a parent and then enters it, Left returns to the
parent and then closes it, Enter and Space pick. The selected row is the
tab stop.

## Callouts → `CoilSidebarCalloutStack`

`CoilSidebarCalloutStack({required List<Widget> children, expand: CoilSidebarCalloutExpand { onHover, never }})`.
Keyed `CoilCard`s, front first, laid out by the `CoilCardStack` primitive.
Up to 2 peek 12 behind the front (top edges, whatever the heights), each
5 % smaller; fanned out, the cards stack by their measured heights with the
tier's gap. `onHover` fans the pile out under a mouse or while focus is
inside, and on touch after a tap on the pile until a tap outside it.
Fanned out, every card takes pointers where it shows; folded, only the
front card does. A dismissed card fades in place while the next moves
forward.

## Settings dialog

`showCoilSettingsDialog<T>({context, required Widget title, required sections, initialSection})`,
`CoilSettingsSection<T>({value, required Widget label, String? semanticLabel, Widget? icon, Widget? description, required WidgetBuilder builder})`,
`CoilSettingsList`, `CoilSettingRow({required Widget label, Widget? description, required Widget trailing})`.

It is an `xl` `CoilDialogFrame`, `min(640, window − 64)` tall, with a
static scaffold (208 wide) whose menu shows focus as the highlight. Under
600 a `CoilSelect` picks the section. On a phone it opens as a sheet.

## Supporting pieces

- `CoilKbd('⇧⌘O')`, `CoilKbd.keys([...])`, `CoilKbd.activator(activator)`.
  Its colors come from the ambient text color, so it suits any surface.
- `CoilDialogFrame({child, onClose, size})`: the dialog's surface and close
  button; `CoilDialog` builds on it.

## Open

- **Header and footer menu width.** FF sizes those menus to the trigger
  plus 10, so items line up with the rows; `CoilDropdown` has no option
  for that yet.

## Kept out on purpose

The icon rail, built-in storage, `railTooltipOpen`, the outline row and
`asChild`.
