# QueuedStack

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/queued_stack.dart';
```

Exports `CoilQueuedMessage`, `CoilQueuedStack`, `CoilQueuedStackLabels`, `CoilQueuedStackStyle`, `CoilQueuedStackTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject queued_stack` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## QueuedStack

- **What it is:** messages sent while a reply streams, waiting in a pile above the composer. The front card is sent next.
- **Anatomy:** a start gutter (an optional glyph, plus the queued count once cards hide behind the pile) → cards → an end gutter of the same width. Gutters are 40 / 32 / 48 and grow with the text.
- **Card:** `accent` mixed 32 % into the background (Oklab), container radius, shadow step 3. Min height control height + 8 (44 / 36 / 52); it grows with the text. The message is a widget (`child`) styled in the subtitle role in `mutedForeground`, one line with an ellipsis; screen readers hear its `semanticLabel`. Up to 3 attachment previews (item inset 8, nested radius) and a "+N" count give way to the text when the card is narrow. Actions are compact ghost icon buttons: edit (an optional slot) and remove (×).
- **Folded:** 2 cards peek out behind the front one, each 12 px higher and 5 % smaller; deeper cards fade out.
- **Fanned out:** each card sits a card plus 8 above the one in front.
- **Pointer:** hover or keyboard focus inside fans it out. A card shows its actions on hover or focus within. Double-click edits. Drag a fanned-out card to reorder.
- **Touch:** a tap fans it out and pins it open. The start gutter becomes a collapse button (chevron down). Actions always show. Drag to reorder.
- **Keyboard:** each card is a tab stop. Enter or F2 edits, Delete or Backspace removes, Alt+↑ / Alt+↓ move the card back or forward.
- **Motion:**
  - fan out and fold on `standard` / `standardExit`;
  - reorders slide on `standard`, and a dragged card follows the finger, lifted to 1.03 on `quick`;
  - a queued card fades in on `fade` and rises 14 from 0.96 on `standard`; a removed one fades on `fadeExit` and shrinks to 0.9 on `standardExit`;
  - a message queued behind the folded pile makes it recoil 7 px on `gentle`. The original uses a one-off spring here (0.42 s, bounce 0.5) that isn't one of its tiers, so coil keeps its own bounciest token.
- **Semantics:** each card is a container labeled "Queued message 2 of 3: text", with an Edit action. The gutter reads "3 queued messages".
- **Layout:** pass the transcript as `child`. The stack fills its space, lays the transcript out under the pile, and adds the folded pile's height (from the cards' real layout, plus the 8 gap) to the transcript's bottom `MediaQuery` padding, so a `ListView` keeps its last message clear. Only the pile's own area fans it out on hover.
- **Not ported:** the queued card morphing into the sent bubble. Flutter has no shared-element transition inside one route.
