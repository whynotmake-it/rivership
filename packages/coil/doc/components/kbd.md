# Kbd

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/kbd.dart';
```

Exports `CoilKbd`, `CoilKbdStyle`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject kbd` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Kbd

- **Anatomy:** one cap per key of a shortcut (`⇧⌘O` → ⇧ ⌘ O; `Ctrl+K` → Ctrl K), 2 apart.
- **Sizes:** 18 square at least (it scales with text), padding 4, 11 type with tabular figures, radius 3. No touch bump; it isn't interactive.
- **Colors:** from the ambient text color: the keys in it, the fill a 15 % wash of it, so the caps suit any surface, the inverted tooltip bubble included.
- **In a tooltip:** the shortcut slot pins the cap to 16, which fits the caption line, so the bubble stays 24 tall.
- **Semantics:** the keys read as one label.
