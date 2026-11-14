# InputMessage

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/input_message.dart';
```

Exports `CoilInputMessage`, `CoilMessageStatus`.

To change its look or composition, eject a copy into your app with `dart run coil:eject input_message` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## InputMessage (chat composer)

- **Anatomy:** a container (hairline, container radius, padding 8) → attachment tray (FileThumbnail 80 tiles, each with a 20 × badge with a 32 / 44 hit) → queue rows (32 / 28 / 44, muted, reorderable) → textarea (subtitle role, 1–10 lines) → toolbar (attach, model, trailing **send button**).
- **Send button:** icon-only primary, 28 / 24 / 36 (44 hit). It morphs **send ↔ stop ↔ queue**. Send and queue share the arrow, so only the swap to and from stop animates, with the blur-fade on `quick`.
- **Queue:** while a reply streams, a draft queues instead of sending. Enter or the queue button hands the trimmed text to `onQueue` and clears the field. With an empty field the button is stop. Without `onQueue`, nothing sends until the reply ends. The app owns the queue: it shows it in a QueuedStack and sends the front message when the reply ends.
- **Behavior:**
  - **Hardware keyboard:** Enter sends, Shift+Enter makes a newline, ↑ in an empty field recalls history.
  - **Touch:** Return inserts a newline; Send is the button.
  - Suggestions: chips above the field (touch: above the keyboard).
- **States:** focus (container border foreground 40 %), drag-over (`brand` 30 % dashed border), disabled, streaming.
- **Motion:** tray, queue and suggestion regions open with height on `standard` and opacity on `fade`; tiles scale 0.9 → 1 on `quick` and siblings slide on `standard`; queue rows reorder on `standard`.
- **Touch:** the tile × and queue × are always visible; swipe a queue row to delete.
- **Semantics:** textField multiline, labeled "Message"; send is a button whose label follows its mode.
