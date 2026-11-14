# Sidebar API

coil's sidebar covers FF's whole surface: three layouts, either side,
resizing, peeking, a phone drawer, two levels of rows with actions and
badges, callouts, and a settings dialog. The shell is composition with
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
| `widthMobile` | none | The drawer is `min(320, 85 %)`, per DESIGN.md. |
| `mobileBreakpoint` 768 | `drawerBreakpoint: 768` | The scaffold's own width, so it works in a pane. |
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
release reopens), and a click folds. Screen readers get increase, decrease
and tap.

**Peek:** while folded, a 12 strip at the edge. `hover` floats the sidebar
out after 150 ms, and so does resting on the folded trigger; `click` does on
press. Escape or a press elsewhere dismisses it, and in hover mode leaving
it does after 250 ms. A tooltip or menu over the card doesn't count as
leaving. The peek card and the column hold the same sidebar (moved with a
`GlobalKey`), so it keeps its state.

**Drawer** (`CoilDrawer`, a new primitive): an `OverlayPortal` descendant
of the scaffold, not a route, so it always shows the app's current state.
It slides on `standard`. The scrim, Escape, system back (through a
`LocalHistoryEntry`, like `Scaffold`) and a drag close it. The drag follows
the finger and hands its velocity to the spring; a fling decides by
direction, a slow release by distance. Focus is trapped inside and restored
on close. A pick in a menu closes it.

**`CoilSidebarTrigger`:** `icon`, `openLabel` / `closeLabel` widgets (with
optional semantic strings). A ghost icon button whose tooltip names the
action and shows the key.

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
Keyed `CoilCard`s, front first. Up to 2 peek 12 behind the front, each 5 %
smaller. `onHover` fans the pile out under a mouse or keyboard focus.
Dismissing the front promotes the next. The pile is as tall as its tallest
card, laid out by its own render box. Touch never fans.

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

- **Rail tooltip.** FF shows "Drag to resize, Click to collapse `[`" beside
  the strip, following the pointer. `CoilTooltip` opens above or below its
  anchor, which doesn't work for a full-height strip, so the rail has no
  tooltip yet.
- **Header and footer menu width.** FF sizes those menus to the trigger
  plus 10, so items line up with the rows; `CoilDropdown` has no option
  for that yet.
- **Edge swipe to open the drawer.** DESIGN.md makes it opt-in on root
  routes; not built yet.

## Kept out on purpose

The icon rail, built-in storage, `railTooltipOpen`, the outline row and
`asChild`.
