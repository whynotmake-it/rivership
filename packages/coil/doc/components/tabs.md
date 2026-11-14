# Tabs

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/tabs.dart';
```

Exports `CoilTab`, `CoilTabLabels`, `CoilTabs`, `CoilTabsStyle`, `CoilTabsTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject tabs` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Tabs

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
