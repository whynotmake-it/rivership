# ChatMessage

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/chat_message.dart';
```

Exports `CoilChatMessage`, `CoilChatMessageAction`, `CoilChatMessageEntrance`, `CoilChatMessageLabels`, `CoilChatMessageStyle`, `CoilChatMessageTrack`, `CoilChatSender`.

To change its look or composition, eject a copy into your app with `dart run coil:eject chat_message` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## ChatMessage

- **Anatomy:** attachments (FileThumbnails 80, gap 6, aligned to the sender's side) → bubble → meta row (time caption muted and actions as icon-only ghost buttons, gap 2).
- **Sizes:** max width 80 %; text is subtitle role; bubble padding 14×8 (compact 12×6; touch 16×10).
- **Variants:**
  - user: a bubble in `accent` mixed 45 % into background (Oklab), container radius, aligned to the end;
  - assistant: no bubble, full width, aligned to the start.
- **Meta row:** pointer shows it on hover or focus within the message; **touch always shows it**. Long-press on touch opens a context menu (Copy, Retry…).
- **Motion:** enter fade + rise 8 + scale 0.96 → 1 on `standard`, from the sender's bottom corner; earlier messages slide to make room on `standard`.
- **Semantics:** each message is a container labeled with sender and time.
