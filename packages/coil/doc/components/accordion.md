# Accordion

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/accordion.dart';
```

Exports `CoilAccordion`, `CoilAccordionItem`, `CoilAccordionMode`, `CoilAccordionStyle`, `CoilAccordionTrack`, `CoilAccordionVariant`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject accordion` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Accordion

- **Anatomy:** items, each a trigger row (label + chevron, trailing) and a collapsible panel (body muted, padding `controlPaddingX` sideways, 12 below). In `group` mode the items share one hover highlight and expanded items get a `hover` tint behind trigger and panel.
- **Sizes:** trigger = §13.1 one-line row; default width 288 (`group`) or full.
- **States:** the label is muted (pointer) or foreground (touch) at rest, foreground when open or hovered, and semibold when open. The chevron rotates 0 → 90° (RTL: 0 → −90°) with icon weight 533 when lit.
- **Modes:** `single` (with `collapsible`) and `multiple`.
- **Motion:** chevron on `quick`; panel height factor on `standard` with opacity on `fade` / `fadeExit`; tint on `fade`.
- **Keyboard:** each trigger is a tab stop; Enter or Space toggles; Up and Down move between triggers in a group.
- **Semantics:** button with `expanded`, and the panel is labelled by its trigger.
- **Touch:** press fill only.
