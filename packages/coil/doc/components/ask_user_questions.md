# AskUserQuestions

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/ask_user_questions.dart';
```

Exports `CoilAnswer`, `CoilAskUserQuestions`, `CoilAskUserQuestionsController`, `CoilAskUserQuestionsLabels`, `CoilAskUserQuestionsStyle`, `CoilAskUserQuestionsTrack`, `CoilQuestion`, `CoilQuestionKeyPosition`, `CoilQuestionKind`, `CoilQuestionLayout`, `CoilQuestionOption`.

To change its look or composition, eject a copy into your app with `dart run coil:eject ask_user_questions` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## AskUserQuestions

- **What it is:** an assistant's questions, one at a time, in a card. A question takes one option (picking it moves on), several options (then Continue), or typed text.
- **Anatomy:** a hairline card (surface 3 light, 2 dark; container radius; max width 520) → "Question 2 of 4" (caption muted) → the question (title role) → option rows, an optional typed "other" row last, or a text field → footer: Back (ghost) at the start; Skip (ghost) and Continue or Finish (primary) at the end. Footer buttons are compact.
- **Geometry:** rows are inset `popupInset` from the card edge, like a popover, so card radius = item radius + inset. Text starts at `popupInset + controlPaddingX`, and the step line, the question and Back's label all align with it.
- **Rows:** §13.1 heights (36 / 28 / 44 / 36), padding `controlPaddingX`. The label is foreground at rest (a question's options are content, not a menu) and semibold with a ghost width when picked. A description follows inline in muted body, or sits under the label in caption (`layout: stacked`).
- **Number keys (pointer only):** each row ends with its number (11/14 micro), or starts with it (`keyPosition: start`). Single choice: a plain number, foreground when picked. Multiple choice: the number in a 20 box (18 compact) with a hairline, filled `foreground` when picked. A lit single-choice row swaps its key for a submit arrow: a `foreground` block 8 larger than the key with a chevron, in on `quick`, out on `quickExit`.
- **States:** the gliding highlight lights rows; picked rows, and the "other" row once it has text, merge into one `active` block (§8.4); one focus ring travels between rows. The "other" field is quiet at rest; while focused and empty it shows a surface fill and a hairline. A rejected free-text answer shows its message under the field (caption `destructive`, live region) and the field turns invalid.
- **Touch:** no number keys and no submit arrow. Rows are 44, rest at full foreground, and show the press fill under a finger. A picked multiple-choice row shows a trailing check instead of a filled key. A tap never pulls focus, so the keyboard stays down until the user taps a field.
- **Motion** (tracks `CoilAskUserQuestionsTrack.height`, `.step`, `.selection`, `.ring`, `.label`, `.hint`, `.press`, `.buttons`): between questions the card's height springs on `standard` while the old question fades out on `fadeExit` (clipped as the card shrinks) and the new one fades in on `fade`. Footer buttons appear and leave with a fade and scale 0.85 on `quick`, and their neighbors slide. Merge/split on `standard`, highlight and ring on `quick`, label weight and key colors on `fade`.
- **Keyboard:** works while focus is in the card. 1 to 9 pick the row with that number; the number after the options focuses the "other" field. Up and Down move between rows with wrapping and don't pick. Enter or Space picks or toggles the focused row. Ctrl+Enter (⌘+Enter on Apple platforms) continues. Escape or the arrow pointing back returns; the arrow pointing forward skips (both flip in RTL). In a text field, digits and arrows edit text, Enter answers, and Shift+Enter is a newline in a multi-line field (touch: Return is a newline and Continue answers). Up and Down in the one-line "other" field return to the rows. When a question changes and focus was in the card, focus moves to the new question's picked row, its first row, or its field.
- **Semantics:** the step line is a live region, so each new question is announced. The question is a header. A single-choice question is a radio group labelled by the question, with radio rows; a multiple-choice one is a group of checked rows. Each row reads its label and description. Keys and the arrow are excluded.
- **API:** `CoilAskUserQuestions<T>(questions:, controller:, onCompleted:, onSkipped:)`. Questions are `CoilQuestion.single`, `.multiple` and `.freeText`; answers are `CoilAnswer<T>` (values, text, skipped) keyed by question id in a `CoilAskUserQuestionsController`. Every visible text (the question, option labels and descriptions, placeholders, button labels, the step line) is a `Widget` the card styles with `DefaultTextStyle`. Strings remain only for screen readers (`semanticLabel`, `otherSemanticLabel`) and for typed answers.
- **Not ported from the web:** the document-wide digit listener (coil scopes keys to the card's focus; pass `autofocus`); the footer's ← and → and ⌘↵ key caps (coil has no key-cap primitive); a growing multi-line "other" field (it is one line, so the keyboard's action button can submit it).
- **Do:** keep it to a few short questions.
- **Don't:** use it for a form the user fills at their own pace (use Field); put more than 9 options in a question (keys stop at 9).

---
