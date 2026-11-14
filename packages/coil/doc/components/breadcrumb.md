# Breadcrumb

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/breadcrumb.dart';
```

Exports `CoilBreadcrumb`, `CoilBreadcrumbLabels`, `CoilBreadcrumbStyle`, `CoilBreadcrumbTrack`, `CoilCrumb`.

To change its look or composition, eject a copy into your app with `dart run coil:eject breadcrumb` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Breadcrumb

- **Anatomy:** a single row of crumbs (body, muted; the current page foreground, not a link). Each crumb ends in a chevron separator (14, muted). "…" opens a menu of the hidden crumbs. A sibling picker on a crumb waits for the Dropdown component.
- **Sizes:** crumb height `controlHeight` (28 on pointer compact by default; 44 hit on touch), padding 6.
- **Collapse:** when the row overflows, the middle crumbs collapse into "…". On phones only the first, "…" and the last two show. The full names of truncated crumbs are reachable in the "…" menu, not only in a tooltip.
- **Motion:** the highlight glides across crumbs on `quick` (pointer).
- **Keyboard:** native Tab order; Enter follows or opens.
- **Semantics:** navigation, labeled "Breadcrumb"; the current page has `selected`.
