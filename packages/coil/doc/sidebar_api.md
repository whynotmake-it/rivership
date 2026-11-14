# Sidebar API design

coil's sidebar today is a fixed-width scaffold, a panel, and a flat menu of
data rows. FF's sidebar covers far more. This note maps every FF part and prop
to a coil widget or parameter. The shell is pure composition with `Widget`
slots. Menu rows stay data entries with widget slots, like `CoilMenuEntry`,
because one highlight layer and one roving-focus list must index rows across
both nesting levels.

Three shared pieces block parts of this. See [Gaps](#gaps).

## Shape at a glance

```dart
final sidebar = CoilSidebarController(open: prefs.open, width: prefs.width)
  ..addListener(() => prefs.save(sidebar.open, sidebar.width));

CoilSidebarScaffold(
  controller: sidebar,
  variant: .inset,
  side: .start,
  peek: .hover,
  sidebar: CoilSidebar(
    header: CoilSidebarBar(
      primary: WorkspaceSwitcher(),
      actions: [CoilSidebarAction(icon: SearchIcon(), tooltip: 'Search', shortcut: '⌘K', onPressed: search)],
    ),
    children: [
      CoilSidebarGroup(
        label: 'Threads',
        expanded: threadsOpen,
        onExpandedChanged: (v) => setState(() => threadsOpen = v),
        actions: [CoilSidebarAction(icon: PlusIcon(), tooltip: 'New thread', onPressed: add)],
        child: CoilSidebarMenu(items: [
          CoilSidebarItem(
            label: 'Fix login',
            status: .unread,
            trailing: Text('4'),
            actions: [/* up to 3 CoilSidebarAction */],
            selected: current == 'login',
            onPressed: () => open('login'),
          ),
          CoilSidebarItem(
            label: 'Agents',
            leading: BrainIcon(),
            expanded: agentsOpen,
            onExpandedChanged: (v) => setState(() => agentsOpen = v),
            children: [CoilSidebarItem(label: 'Research', onPressed: () {})],
          ),
        ]),
      ),
    ],
    footer: Column(children: [
      CoilSidebarCalloutStack(children: [/* keyed CoilCards */]),
      CoilSidebarBar(primary: UserMenu(), actions: [/* settings */]),
    ]),
  ),
  body: Column(children: [
    Row(children: [CoilSidebarTrigger(icon: PanelIcon())]),
    Expanded(child: page),
  ]),
)
```

## Shell: `SidebarProvider` + `Sidebar` → `CoilSidebarScaffold`

FF splits state (provider) from layout (`Sidebar`, `SidebarInset`). In
Flutter the scaffold owns both, like `Scaffold` owns its drawer.
`SidebarInset` becomes the `body:` slot.

| FF | coil | Notes |
|---|---|---|
| `open`, `onOpenChange`, `defaultOpen` | `controller: CoilSidebarController?` | `ChangeNotifier` with `open`, `width`, `toggle()`. Null: the scaffold owns one, opened, 256 wide. |
| `persist` (cookie) | none built in | The app listens to the controller and saves `open` and `width`, then restores by constructing the controller with them. The drawer state is never stored. |
| `width` | `CoilSidebarController.width` | Starting width; the rail updates it. |
| `widthMobile` | none | The drawer is `min(320, 85 %)` per DESIGN.md. |
| `mobileBreakpoint` 768 | `drawerBreakpoint: double = 768` | The scaffold's own width, not the window's, so it works in a pane. |
| `shortcut` | `shortcuts: Set<ShortcutActivator>?` | Null: bare `[` for a sidebar on the left, `]` on the right, plus ⌘B / Ctrl+B. Empty disables. |
| `peek` | `peek: CoilSidebarPeek { none, hover, click }` | |
| `side` | `side: CoilSidebarSide { start, end }` | Directional, so RTL mirrors. The default key follows the physical edge. |
| `variant` | `variant: CoilSidebarVariant { sidebar, floating, inset }` | Inset draws `body` as a raised card with an 8 margin. |
| `collapsible` | `collapsible: CoilSidebarCollapsible { offcanvas, none }` | `none`: a static column, no rail, no drawer, no shortcut. **No icon rail**, on purpose. |
| `rail` | `rail: Widget? = const CoilSidebarRail()` | Null hides it; trigger and shortcut still toggle. |
| `railTooltipOpen` | dropped | Only FF's docs use it, to spotlight the handle. |
| `bordered` | `CoilSidebarStyle.edgeColor` | Look, so it lives in the style. |
| min / max / slop | `minWidth: 160`, `maxWidth: 360` | The 56 collapse slop is internal. |
| `motion` | `motion:` + `motions: Map<CoilSidebarTrack<Object>, Motion>?` | Tracks: `width` (gentle), `peek` (standard), `highlight` (quick), `selection` (standard), `expand` (standard). |

`CoilSidebarScaffold.of(context)` returns the controller, for a custom
trigger.

### Shortcut scope

Flutter's `Shortcuts` are focus-scoped already, so the innermost scaffold
holding focus answers and a nested one wins over its shell. The action is
disabled while focus is in a text field, so `[` still types. FF also lets the
outermost provider answer when nothing has focus. The scaffold gets that with
a `Focus(autofocus: true, skipTraversal: true)` around itself: autofocus only
takes focus when nothing in the route has it. **Decision needed:** keep that,
or answer only while focus is inside.

### Rail, peek and drawer

- **`CoilSidebarRail`**, pointer only: an 8-wide strip on the inner edge with
  a resize cursor. Hover brightens the hairline. A drag resizes 1:1 between
  `minWidth` and `maxWidth`. Dragging 56 past the minimum previews the
  collapse, and pulling back re-opens before release. A click collapses.
  Screen readers get increase, decrease and tap actions.
- **Peek:** while collapsed, a 12-wide edge strip. `hover` floats the real
  sidebar out after 150 ms, and resting on the collapsed trigger does too.
  `click` floats it on press. Escape or an outside press dismisses, and
  leaving it dismisses after 250 ms. Peeking never changes `open`, and it
  stays while a popup opened from inside the card is open.
- **Drawer:** below `drawerBreakpoint`, `toggle()` opens a modal drawer from
  the scaffold's side. A pick closes it, and so does system back.

### `CoilSidebarTrigger`

`CoilSidebarTrigger({required Widget icon, String expandLabel, String collapseLabel})`:
a ghost icon button that calls `toggle()`. Its tooltip names the action and
shows the shortcut key. In hover-peek mode, a collapsed trigger also peeks.
The icon is a slot because coil bundles no icons.

## Panel: `SidebarHeader` / `SidebarContent` / `SidebarFooter` → `CoilSidebar`

`CoilSidebar({Widget? header, required List<Widget> children, Widget? footer, CoilSidebarStyle? style})`.
`children` scroll in a `CoilScrollArea` with edge fades. Header and footer
stay pinned.

**Stacking** is composition, not a prop:

- Vertical: a `Column` of a primary element (switcher, user row) and a
  `CoilSidebarMenu` of action rows.
- Horizontal: `CoilSidebarBar({required Widget primary, List<Widget> actions})`
  puts the primary element first and 1 to 3 `CoilSidebarAction`s after it,
  on the rows' trailing action axis.

**The 24 rhythm:** `CoilSidebarAction({required Widget icon, required String semanticLabel, String? tooltip, String? shortcut, VoidCallback? onPressed})`
is the one 24-px ghost icon button (16 icon, gap 4) that the header,
group labels, rows and footer all use. On touch its hit area is 44. A
dropdown trigger passes no `tooltip`.

`SidebarSeparator` → `CoilSidebarSeparator`. `SidebarInput` → a compact
`CoilInput` in the header; no sidebar-specific field.

## Sections: `SidebarGroup*` → `CoilSidebarGroup`

`CoilSidebarGroup({String? label, required Widget child, List<Widget> actions, bool expanded = true, ValueChanged<bool>? onExpandedChanged})`.

- With `onExpandedChanged`, the label is a toggle. Hover raises its contrast
  and reveals a chevron, which stays visible while closed. On touch the
  chevron always shows. The content collapses with `CoilCollapsible`.
- Without it, the label is a static caption.
- `actions` holds 1 to 3 `CoilSidebarAction`s, always visible. The label
  keeps its chevron one gap clear of them.
- Controlled, like every coil value. FF's uncontrolled `defaultOpen` is not
  offered.

## Rows: `SidebarMenu*` → `CoilSidebarMenu` + `CoilSidebarItem`

`CoilSidebarMenu({required List<CoilSidebarItem> items, CoilSidebarMenuFocus focus = .ring, CoilSize? size, String? semanticLabel})`.
One hover highlight glides across both levels. Each level has its own
selected fill. `focus: .highlight` moves the hover fill instead of drawing a
ring, for the settings dialog.

`CoilSidebarItem` (immutable):

| FF | coil |
|---|---|
| children text | `label: String` (typeahead, semantics); `child: Widget?` overrides the visual, such as a two-line row. Heights are minimums, so FF's `size: "lg"` isn't needed. |
| `icon` | `leading: Widget?`, styled by `IconTheme`; weight thickens when lit. |
| `status` | `status: CoilSidebarStatus? { active, unread, idle }`: a dot when there is no `leading`; `unread` is announced; `active` implies selected. |
| `dot` | `leading: CoilSidebarDot(.filled / .ring)` |
| `isActive` | `selected: bool` |
| `SidebarMenuBadge` | `trailing: Widget?`, a 24 slot on the rightmost axis. |
| `SidebarMenuAction(s)`, `showOnHover` | `actions: List<Widget>` (1 to 3) + `actionsVisibility: CoilSidebarActionsVisibility { hover, always }`. Hover reveals them on pointer while the row is hovered or focused or one of its menus is open. **Touch always shows them**, as DESIGN.md says. The label claims their width only while they show. |
| `SidebarMenuSub`, `SidebarMenuSubButton` | `children: List<CoilSidebarItem>` + `expanded` + `onExpandedChanged`. Two levels only; a child's `children` asserts. Sub-rows are 28, indented so the label lines up with the parent's. |
| `onClick` | `onPressed`; null with no children disables. A parent with no `onPressed` toggles. |
| `variant: "outline"`, `render` / `asChild` | dropped; `child` covers custom content. |
| `SidebarMenuSkeleton` | a `CoilSkeletonRegion` around skeleton rows; no new widget. |

**Keyboard:** Up and Down rove across visible rows of both levels, Home and
End jump, Right opens a parent and Left closes it or goes to the parent,
Enter and Space pick. Selected rows are the tab stops.

## Callouts → `CoilSidebarCalloutStack`

`CoilSidebarCalloutStack({required List<Widget> children, CoilCalloutStackExpand expand = .onHover})`.
Children are keyed `CoilCard`s: inline with an `icon` for FF's inline
callouts, stacked with `media` for banners. At rest the front card shows with
up to 2 cards peeking 12 behind it, each 5 % smaller. `onHover` fans the pile
out on pointer hover; banners use `.never`. Dismissing the front card
promotes the next. Touch never fans. A single callout is just a `CoilCard`.

## Settings dialog block

`showCoilSettingsDialog<T>({context, title, sections, initialSection})` with
`CoilSettingsSection<T>({value, label, icon, description, builder})` and
`CoilSettingRow({label, description, trailing})`.

- Wide: an `xl` dialog, `min(640, window − 64)` tall, with a
  `CoilSidebarScaffold(collapsible: .none, width: 208)` holding a
  `CoilSidebarMenu(focus: .highlight)`. The panel shows the section title,
  description and a scrolling body.
- Under 600: the sidebar hides and a `CoilSelect` picks the section. On the
  touch tier it opens as a sheet, like a form dialog.

## Gaps

These need changes in shared pieces I don't own. Each is small.

1. **Tooltip shortcut and rich content.** The trigger's tooltip shows the
   key, and the rail's tooltip is two lines ("Drag to resize", "Click to
   collapse `[`"). `CoilTooltip` only takes a `String`. Proposal:
   `CoilTooltip(shortcut: String?)` drawing a key chip, plus
   `CoilTooltip.rich(content: Widget, semanticLabel)`. coil has no key-chip
   widget yet; the search field's `⌘K` needs one too.
2. **Drawer edge and drag.** `CoilModalPresentation.drawer` only slides from
   the start edge, on `gentle`. DESIGN.md wants `standard`, a drag that
   follows the finger and releases with velocity, and an end-edge drawer
   for `side: .end`. Proposal: `showCoilModal(edge: AxisDirection?)` and a
   drag-to-dismiss like the sheet's.
3. **A dialog frame without fixed anatomy.** `CoilDialog` always lays out
   title, description, body and actions inside padding. The settings dialog
   needs the same surface, width and close button around its own two-column
   layout. Proposal: extract a public `CoilDialogFrame({child, onClose, size})`
   that `CoilDialog` itself builds on.

Optional: FF sizes the header and footer menus to the trigger + 10 so items
land on the rows' axes. `CoilDropdown` has no popup-width option; without
one, those menus use the default width.

## Kept out on purpose

- The icon rail (`collapsible: "icon"`).
- Built-in storage.
- `railTooltipOpen`, the outline row and `asChild`.
